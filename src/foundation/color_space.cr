# TLDR; What functionality is in here?
# Color math foundation: converts between sRGB hex values and CIELAB so perceptual distance can be measured.

module Foundation
  # CIELAB is calculated relative to these XYZ D65 reference white values.
  # Shared by both directions of the sRGB <-> CIELAB conversion.
  private WHITE_X = 0.95047
  private WHITE_Y =     1.0
  private WHITE_Z = 1.08883

  # A CIELAB color using D65 reference white. Used for perceptual color distance.
  # References for color constants and calculations for sRGB D65
  # - [http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html](http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html)
  # - [https://github.com/lucasb-eyer/go-colorful/blob/master/colors.go](https://github.com/lucasb-eyer/go-colorful/blob/master/colors.go)
  #
  # Meta: Reopened so these methods live outside the `record` macro block but are still attached to the same struct.
  # Why do this? Because the `crystal docs` commands' `wants_doc` parser chokes on method docstring comments under the `record` macro.
  record Lab,
    l : Float64,
    a : Float64,
    b : Float64

  struct Lab
    # ΔE76: the Euclidean distance between two Lab colors. Larger is more perceptually different.
    def distance(other : Lab) : Float64
      Math.sqrt((l - other.l) ** 2 + (a - other.a) ** 2 + (b - other.b) ** 2)
    end

    # Inverse of `RGB#to_lab`, converts this CIELAB color back to 8bit sRGB (D65).
    #
    # Out-of-gamut Lab values are clamped into the sRGB cube, so this method always returns a valid `RGB` and never raises.
    # A round-trip may differ by +/-1 per channel because each trip rounds the conversion independently.
    def to_rgb : RGB
      fy = (l + 16.0) / 116.0
      fx = fy + a / 500.0
      fz = fy - b / 200.0

      # CIELAB -> CIE XYZ (D65)
      x = lab_f_inv(fx) * WHITE_X
      y = lab_f_inv(fy) * WHITE_Y
      z = lab_f_inv(fz) * WHITE_Z

      # CIE XYZ (D65) -> linear sRGB
      rl = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
      gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
      bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z

      RGB.new(delinearize(rl), delinearize(gl), delinearize(bl))
    end

    # Inverse of `RGB#lab_f`: converts a CIELAB component back to a linear XYZ ratio.
    private def lab_f_inv(ft : Float64) : Float64
      cube = ft ** 3
      cube > 0.008856451679035631 ? cube : (ft - 16.0 / 116.0) / 7.787037037037035
    end

    # Converts a linearized sRGB channel [0.0, 1.0] back to an 8-bit value by
    # applying the inverse sRGB gamma curve (i.e. re-introducing the nonlinear
    # encoding that was removed by linearization), clamping out-of-gamut input
    # into range first.
    private def delinearize(channel : Float64) : UInt8
      c = channel.clamp(0.0, 1.0)
      v = c <= 0.0031308 ? c * 12.92 : 1.055 * (c ** (1.0 / 2.4)) - 0.055
      (v * 255.0).round.clamp(0.0, 255.0).to_u8
    end
  end

  # An 8bit sRGB color: the base color value for hex parsing and downsampling.
  #
  # ```
  # rgb = Foundation::RGB.parse("#FF8800")
  # rgb.r      # => 255
  # rgb.g      # => 136
  # rgb.b      # => 0
  # rgb.to_hex # => "#ff8800"
  # ```
  struct RGB
    getter r : UInt8
    getter g : UInt8
    getter b : UInt8

    def initialize(@r : UInt8, @g : UInt8, @b : UInt8)
    end

    # Parses a *hex* color: "#RGB" (with each nibble doubled) or "#RRGGBB". Case insensitive.
    #
    # Raises on a malformed *hex*.
    def self.parse(hex : String) : RGB
      unless hex.starts_with?('#')
        raise ArgumentError.new("invalid hex color #{hex.inspect}: expected leading '#'")
      end
      body = hex[1..]
      case body.size
      when 3
        # The first digit carries place value 16, and the second carries place value 1.
        # So multiply the first digit by 16 + 1 = 17 = 0x11.
        new(
          (digit(hex, body[0]) * 0x11).to_u8,
          (digit(hex, body[1]) * 0x11).to_u8,
          (digit(hex, body[2]) * 0x11).to_u8,
        )
      when 6
        # The first digit carries place value 16, and the second carries place value 1.
        # So multiply the high-nibble by 16 and add the low-nibble to assemble the two-digit base16 number.
        new(
          (digit(hex, body[0]) * 16 + digit(hex, body[1])).to_u8,
          (digit(hex, body[2]) * 16 + digit(hex, body[3])).to_u8,
          (digit(hex, body[4]) * 16 + digit(hex, body[5])).to_u8,
        )
      else
        raise ArgumentError.new("invalid hex color #{hex.inspect}: expected #RGB or #RRGGBB")
      end
    end

    # Converts a single hex digit to its 0-15 value, raising with the full *hex* context if *char* is not actually a hexadecimal digit.
    private def self.digit(hex : String, char : Char) : Int32
      char.to_i?(16) ||
        raise ArgumentError.new("invalid hex color #{hex.inspect}: '#{char}' is not a hex digit")
    end

    # Formats *string* as a lowercase "#RRGGBB" string.
    def to_hex : String
      "#%02x%02x%02x" % [@r, @g, @b]
    end

    # Linearizes each sRGB channel and converts to CIELAB (with D65 reference white) to return a `Lab` value.
    def to_lab : Lab
      rl = linearize(@r)
      gl = linearize(@g)
      bl = linearize(@b)

      # Linear sRGB -> CIE XYZ (D65)
      x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl
      y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
      z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl

      fx = lab_f(x / WHITE_X)
      fy = lab_f(y / WHITE_Y)
      fz = lab_f(z / WHITE_Z)
      Lab.new(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))
    end

    # Compares the Lab representations between `self` and *other*.
    # Returns the ΔE76 perceptual distance between the two.
    def distance(other : RGB) : Float64
      to_lab.distance(other.to_lab)
    end

    # Blends toward *other* through CIELAB, returning the interpolated s*RGB* color.
    #
    # *t* is the mix fraction clamped to 0.0..1.0, where `t == 0.0` returns `self` and `t == 1.0` returns `other`.
    # Blending in Lab rather than sRGB keeps the gradient perceptually even.
    def blend(other : RGB, t : Float64) : RGB
      amount = t.clamp(0.0, 1.0)
      # Return the endpoints exactly. a to_lab/to_rgb round-trip is lossy, so short-circuiting is both correct and cheaper.
      return self if amount == 0.0
      return other if amount == 1.0

      from = to_lab
      dest = other.to_lab
      Lab.new(
        from.l + (dest.l - from.l) * amount,
        from.a + (dest.a - from.a) * amount,
        from.b + (dest.b - from.b) * amount,
      ).to_rgb
    end

    # Expands an 8-bit sRGB *channel* value (0–255) to a linearized light intensity in [0.0, 1.0], applying the sRGB piecewise transfer function (gamma).
    private def linearize(channel : UInt8) : Float64
      v = channel / 255.0
      v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
    end

    # Converts a normalized XYZ component *t* into the value used by the CIELAB formulas. This is one step of the XYZ -> CIELAB conversion.
    # For values above a small threshold it takes the cube root.
    # For smaller values it falls back to a linear approximation to avoid the cube root's steep slope near zero.
    private def lab_f(t : Float64) : Float64
      t > 0.008856451679035631 ? Math.cbrt(t) : 7.787037037037035 * t + 16.0 / 116.0
    end
  end
end
