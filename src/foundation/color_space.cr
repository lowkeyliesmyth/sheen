module Foundation
  # A CIELAB color using D65 reference white. Used for perceptual color distance.
  # References for color constants and calculations for sRGB D65
  # - http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
  # - https://github.com/lucasb-eyer/go-colorful/blob/master/colors.go
  struct Lab
    getter l : Float64
    getter a : Float64
    getter b : Float64

    def initialize(@l : Float64, @a : Float64, @b : Float64)
    end

    # ΔE76: the Euclidean distance between two Lab colors. Larger is more perceptually different.
    def distance(other : Lab) : Float64
      Math.sqrt((@l - other.l) ** 2 + (@a - other.a) ** 2 + (@b - other.b) ** 2)
    end
  end

  # An 8bit sRGB color: the base color value for hex parsing and downsampling.
  struct RGB
    # CIELAB is calculated relative to these XYZ D65 reference white values
    private WHITE_X = 0.95047
    private WHITE_Y =     1.0
    private WHITE_Z = 1.08883

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

    # Expands an 8-bit sRGB *channel* value (0–255) to a linearized light intensity in [0.0, 1.0], applying the sRGB piecewise transfer function (gamma).
    private def linearize(channel : UInt8) : Float64
      v = channel / 255.0
      v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
    end

    # Applies the CIE standard piecewise cube-root nonlinearity to a normalized XYZ component *t*, returning the linearized value for use in CIELAB conversion.
    private def lab_f(t : Float64) : Float64
      t > 0.008856451679035631 ? Math.cbrt(t) : 7.787037037037035 * t + 16.0 / 116.0
    end
  end
end
