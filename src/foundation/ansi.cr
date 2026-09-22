# TLDR; What functionality is in here?
# Low-level ANSI escape model: recognizes, strips, and decomposes CSI/OSC/SGR sequences into structured color and attribute state.
require "./sgr"

module Foundation
  # String Terminator for OSC sequences
  ST = "\e\\"

  # Closes any open hyperlink span, to be placed after the linked text.
  RESET_HYPERLINK = "\e]8;;\e\\"

  # Matches a single ANSI escape sequence: CSI, OSC (Operating System Command) with BEL (Bell) or ST (String Terminator), or two byte ESC.
  # No need for full parsing here, a regex is sufficient for stripping these.
  ESCAPE_PATTERN = /
      \e\[ [\x30-\x3F]* [\x20-\x2F]* [\x40-\x7E]  # CSI
      |
      \e\] .*? (?: \x07 | \e\\ )                  # OSC (terminated by BEL or ST)
      |
      \e [\x20-\x7E]                              # other two-byte ESC
    /x

  # Strips all ANSI escape sequences from *string*, leaving only printable content.
  def self.strip(string : String) : String
    string.gsub(ESCAPE_PATTERN, "")
  end

  # Opens a hyperlink span pointing to *url*.
  # Optional *params* are encoded as k=v pairs joined by ':'.
  #
  # Trust the caller. Caller is responsible for ensuring that *url*  is free of control characters.
  def self.hyperlink(url : String, **params) : String
    param_str = params.empty? ? "" : params.map { |k, v| "#{k}=#{v}" }.join(':')
    "\e]8;#{param_str};#{url}\e\\"
  end

  # SGR 4-bit basic color: index 0..15
  record BasicColor, index : UInt8 # 0..15 -> 30-37/90-97 (fg), 40-47/100-107(bg)
  # SGR 8-bit 256-color palette index: 0..255
  record IndexedColor, index : UInt8 # 0..255 -> 38;5;n (fg) / 48;5;n (bg)
  # SGR 24-bit truecolor value
  record RGBColor, r : UInt8, g : UInt8, b : UInt8 # -> 38;2;r;g;b (fg) / 48;2;r;g;b (bg)

  # The terminal default fg/bg (SGR 39 / 49). Is a sentinel type used to distinguish explicit default colors from actively defined overrides.
  struct DefaultColor
  end

  # Any SGR level color a parsed sequence can carry
  alias SGRColor = BasicColor | IndexedColor | RGBColor | DefaultColor

  @[Flags]
  # Bool SGR text attributes, stored as a bitset
  enum SGRFlags
    Bold
    Faint
    Italic
    Blink
    Reverse
    Strikethrough
  end

  # The decomposed, accumulated result of parsing one or more SGR sequences.
  #
  # 0 (reset) clears all sequences seen up to that point.
  record Attributes,
    flags : SGRFlags = SGRFlags::None,
    underline : Underline? = nil,
    fg : SGRColor? = nil,
    bg : SGRColor? = nil,
    reset : Bool = false,
    unknown : Array(String) = [] of String

  # The decomposed, accumulated result of parsing one or more SGR sequences.
  #
  # 0 (reset) clears all sequences seen up to that point.
  # Meta: Reopened so these methods live outside the `record` macro block but are still attached to the same struct.
  # Why do this? Because the `crystal docs` commands' `wants_doc`  parser chokes on method docstring comments under the `record` macro.
  struct Attributes
    # Serializes the attributes to an SGR escape sequence and writes it to *io*.
    # Applies accumulated state in order.
    #
    # Round-trips are intentionally semantically accurate, not byte-accurate.
    def to_s(io : IO) : Nil # ameba:disable Metrics/CyclomaticComplexity
      style = Style.new
      style.reset if reset
      style.bold if flags.bold?
      style.faint if flags.faint?
      style.italic if flags.italic?
      style.blink if flags.blink?
      style.reverse if flags.reverse?
      style.strikethrough if flags.strikethrough?
      if u = underline
        u.single? ? style.underline : style.underline_style(u)
      end
      if f = fg
        emit_color(style, f, true)
      end
      if b = bg
        emit_color(style, b, false)
      end
      unknown.each do |param|
        style.raw(param)
      end
      style.to_s(io)
    end

    # Emits an SGR color sequence for **color** to **style*, targeting foreground or background based on **foreground**.
    private def emit_color(style : Style, color : SGRColor, foreground : Bool) : Nil
      case color
      in BasicColor
        foreground ? style.foreground_basic(color.index) : style.background_basic(color.index)
      in IndexedColor
        foreground ? style.foreground_indexed(color.index) : style.background_indexed(color.index)
      in RGBColor
        foreground ? style.foreground_rgb(color.r, color.g, color.b) : style.background_rgb(color.r, color.g, color.b)
      in DefaultColor
        foreground ? style.default_foreground : style.default_background
      end
    end
  end

  # Matches a single SGR sequence, capturing its parameter bytes (digits, ';', and ':')
  SGR_PATTERN = /\e\[([0-9;:]*)m/

  # Parse every SGR sequence in **string** and merge them into one `Attributes` object.
  # Text, OSC, and non-SGR escapes are ignored. Malformed SGR input is stored as unknown and does not raise.
  def self.parse_sgr(string : String) : Attributes
    state = SGRState.new
    string.scan(SGR_PATTERN) do |match|
      state.apply(match[1])
    end
    state.to_attributes
  end

  # Accumulate SGR state across sequences in the order they are applied.
  #
  # Similar to `Style`, using a Class and not struct here because structs copy on every method call which breaks chainable mutation.
  private class SGRState
    @flags = SGRFlags::None
    @underline : Underline? = nil
    @fg : SGRColor? = nil
    @bg : SGRColor? = nil
    @reset = false
    @unknown = [] of String

    # Parse and apply SGR escape sequence **params** (bytes between `\e[` and `m`) in order.
    def apply(params : String) : Nil
      tokens = params.split(';')
      index = 0
      while index < tokens.size
        consumed = apply_token(tokens, index)
        # Raise on the possibility of a parser bug being introduced in the future (not malformed input BTW) which should never happen, but because it's challenging to test for such a bug let's make sure it never escapes and raise here just in case it does happen.
        # This loop works in steady state because every `apply_token` branch consumes at least 1 token. Any non-positive return would spin this loop (and the caller's terminal) forever, so raising with the token that stalled is less bad than choking forever.
        raise "BUG: apply_token consumed #{consumed} tokens at #{tokens[index].inspect} in #{params.inspect}" if consumed < 1
        index += consumed
      end
    end

    # Parse and apply one complete SGR **sequence**.
    #
    # Ignores any input that isn't exactly one complete single SGR sequence.
    def apply_sequence(sequence : String) : Nil
      return unless match = SGR_PATTERN.match(sequence)
      return unless match[0] == sequence

      apply(match[1])
    end

    # Return whether or not the current accumulated state has "active" styling that has to be reset by the line boundary so it doesn't bleed over.
    def active? : Bool
      @flags != SGRFlags::None ||
        active_underline? ||
        active_color?(@fg) ||
        active_color?(@bg)
    end

    # Return a standard SGR sequence that recreates the effective accumulated state.
    #
    # "Reset", unknown params, explicit references to default colors, and `Underline::None` don't need restoration after a reset so they aren't included in this recreation.
    def sequence : String # ameba:disable Metrics/CyclomaticComplexity
      style = Style.new

      style.bold if @flags.bold?
      style.faint if @flags.faint?
      style.italic if @flags.italic?
      style.blink if @flags.blink?
      style.reverse if @flags.reverse?
      style.strikethrough if @flags.strikethrough?

      if underline = @underline
        unless underline.none?
          underline.single? ? style.underline : style.underline_style(underline)
        end
      end

      if color = @fg
        style.foreground(color) unless color.is_a?(DefaultColor)
      end

      if color = @bg
        style.background(color) unless color.is_a?(DefaultColor)
      end

      style.to_s
    end

    # Record accumulated SGR state as an `Attributes` object.
    def to_attributes : Attributes
      Attributes.new(@flags, @underline, @fg, @bg, @reset, @unknown)
    end

    # Apply the SGR escape **tokens** entry at **index** to state. Return the number of tokens processed in each run.
    #
    # Each SGR escape entry counts as exactly one token, except for extended colors which are generally >1.
    #
    # See for reference: https://en.wikipedia.org/wiki/ANSI_escape_code#Select_Graphic_Rendition_parameters
    private def apply_token(tokens : Array(String), index : Int32) : Int32 # ameba:disable Metrics/CyclomaticComplexity
      token = tokens[index]
      case token
      when "", "0"             then apply_reset
      when "1"                 then @flags |= SGRFlags::Bold # bitwise OR assignment operator
      when "2"                 then @flags |= SGRFlags::Faint
      when "3"                 then @flags |= SGRFlags::Italic
      when "4"                 then @underline = Underline::Single
      when .starts_with?("4:") then apply_underline_style(token) # some terms support underline style extensions
      when "5"                 then @flags |= SGRFlags::Blink
      when "7"                 then @flags |= SGRFlags::Reverse
      when "9"                 then @flags |= SGRFlags::Strikethrough
      when "22"                then @flags &= ~(SGRFlags::Bold | SGRFlags::Faint) # bitwise AND assignment and NOT operator
      when "23"                then @flags &= ~SGRFlags::Italic
      when "24"                then @underline = nil
      when "25"                then @flags &= ~SGRFlags::Blink
      when "27"                then @flags &= ~SGRFlags::Reverse
      when "29"                then @flags &= ~SGRFlags::Strikethrough
      when "38"                then return apply_extended_color(tokens, index, foreground: true)
      when "39"                then @fg = DefaultColor.new
      when "48"                then return apply_extended_color(tokens, index, foreground: false)
      when "49"                then @bg = DefaultColor.new
      else                          apply_basic_color(token) # catch-all for 30-37/90-97 fg, 40-47/100-107 bg colors, or unknowns
      end
      1
    end

    # Handle SGR 0 or an empty parameter by clearing accumulated `SGRState` and recording a reset event.
    private def apply_reset : Nil
      @flags = SGRFlags::None
      @underline = nil
      @fg = nil
      @bg = nil
      @unknown.clear
      @reset = true
    end

    # Parse and apply an underline substyle SGR escape **token** (`4:n`).
    #
    # Is classified as `@unknown` if the *n* subtokens are not actually valid `Underline` values.
    private def apply_underline_style(token : String) : Nil
      if style = token[2..].to_i?.try { |value| Underline.from_value?(value) }
        @underline = style
      else
        @unknown << token
      end
    end

    # Apply the extended color **tokens** (SGR `38` or `48`) starting at the SGR sequence **index**.
    #
    # Associate and consume the following 8-bit IndexedColor (`5;n`) or 24-bit TrueColor (`2;r;g;b`) subtokens following the introducer token. Return the total number of tokens consumed across both introducer and subtokens.
    #
    # If subtokens are missing or invalid then *only the introducer* is consumed and is classified as `@unknown`. Remaining leftover subtokens are re-read as ordinary SGR sequences.
    # Why? Because consuming the whole group would append to the single shared `@unknown` entry, be flattened by `Attributes#to_s` and reparsed in a new potentially valid but nondeterministic new combination with broadly unexpected results.
    private def apply_extended_color(tokens : Array(String), index : Int32, foreground : Bool) : Int32
      case tokens[index + 1]?
      #  ITU's T.416 subtype 0( "implementation-defined",  wtf even is that) and 1 (transparent) are not actually used by Sheen so are safe to eat, and don't have extra parameters so have a standard width making them low-effort to handle here. So eat these erroneous subtokens and group them with the introducer token to prevent an accidental (eg `\e[38;0m`) state clearing by processing SGR 0 on its own.
      when "0", "1"
        @unknown << tokens[index, 2].join(';')
        return 2
      when "5"
        if n = u8_at(tokens, index + 2)
          set_color(IndexedColor.new(n), foreground)
          return 3
        end
      when "2"
        r, g, b = u8_at(tokens, index + 2), u8_at(tokens, index + 3), u8_at(tokens, index + 4)
        if r && g && b
          set_color(RGBColor.new(r, g, b), foreground)
          return 5
        end
      end
      @unknown << tokens[index]
      1
    end

    # Apply a basic color **token** (30-37/90-97 fg, 40-47/100-107 bg) if input is valid.
    #
    # Classifies any invalid input as `@unknown`.
    private def apply_basic_color(token : String) : Nil
      case code = token.to_i?
      # Handle any random junk caught by the catchall
      when Nil      then @unknown << token
      when 30..37   then @fg = BasicColor.new((code - 30).to_u8)
      when 90..97   then @fg = BasicColor.new((code - 90 + 8).to_u8)
      when 40..47   then @bg = BasicColor.new((code - 40).to_u8)
      when 100..107 then @bg = BasicColor.new((code - 100 + 8).to_u8)
      else
        # Handle any invalid basic color indices
        @unknown << token
      end
    end

    # Assign provided **color** to the foreground if **foreground** is true, otherwise assign to the background.
    private def set_color(color : SGRColor, foreground : Bool) : Nil
      if foreground
        @fg = color
      else
        @bg = color
      end
    end

    # Return **tokens** at the **index** position as a `UInt8` if valid, or `nil` if invalid.
    private def u8_at(tokens : Array(String), index : Int32) : UInt8?
      tokens[index]?.try(&.to_u8?)
    end

    # Return whether **color** is an actively defined color override or not.
    private def active_color?(color : SGRColor?) : Bool
      !color.nil? && !color.is_a?(DefaultColor)
    end

    # Assess and return whether an underline state is an actively defined underline or not.
    private def active_underline? : Bool
      @underline.try(&.none?) || false
    end
  end

  # The classification of a segment yielded by the `each_segment` method
  # TODO: Fix SGR and OSC capitalization
  enum SegmentKind
    Text   # printable content of zero or more graphemes
    Sgr    # an SGR sequence (`\e[...m`)
    Osc    # an OSC sequence, eg an OSC8 hyperlink
    Escape # any other escape sequence
  end

  # Split **string** into ordered text and escape segments.
  #
  # Complete CSI and OSC sequences are yielded as atomic units. An unterminated CSI/OSC sequence consumes the remainder of the string and treats it as an opaque escape segment.
  def self.each_segment(string : String, & : SegmentKind, String ->) : Nil
    cursor = 0

    while cursor < string.bytesize
      length, kind = next_segment(string, cursor)
      yield kind, string.byte_slice(cursor, length)
      cursor += length
    end
  end

  # Return the byte length and kind of the next segment beginning from **start** byte of **string**.
  private def self.next_segment(string : String, start : Int32) : Tuple(Int32, SegmentKind)
    unless string.byte_at?(start) == 0x1B # CSI `\e`
      return {text_length(string, start), SegmentKind::Text}
    end

    case string.byte_at?(start + 1)
    when 0x05B # [
      csi_segment(string, start)
    when 0x05D # ]
      osc_segment(string, start)
    else
      {Math.min(2, string.bytesize - start), SegmentKind::Escape}
    end
  end

  # Return the number of bytes before the next ESC or the end of the **string**, beginning from **start** byte.
  private def self.text_length(string : String, start : Int32) : Int32
    index = start + 1
    while index < string.bytesize && string.byte_at(index) != 0x1B # CSI ESC `\e`
      index += 1
    end
    index - start
  end

  # Return the byte length and kind of the CSI sequence **string**, beginning from **start** byte.
  #
  # Returns as an Escape kind if the sequence never terminates or is interrupted by a new ESC sequence.
  private def self.csi_segment(string : String, start : Int32) : Tuple(Int32, SegmentKind)
    # Account for the leading `[`
    index = start + 2

    while index < string.bytesize
      byte = string.byte_at(index)

      # Abort a CSI when a new ESC arrives.
      # Without this guard the scan would treat the next sequence's `[` (0x5B) as a final byte and leak its parameters as visible text
      return {index - start, SegmentKind::Escape} if byte == 0x1B # CSI ESC `\e`

      # ANSI CSI sequence final bytes range
      if byte.in?(0x40..0x7E)
        kind = byte == 0x6D ? SegmentKind::Sgr : SegmentKind::Escape # `m` indicates successful SGR termination
        return {index - start + 1, kind}
      end
      index += 1
    end
    {string.bytesize - start, SegmentKind::Escape}
  end

  # Return the byte length and kind of the OSC sequence **string**, beginning from **start** byte.
  #
  # Returns as an Escape kind if the sequence never terminates or is interrupted by an ESC that does not begin an ST.
  private def self.osc_segment(string : String, start : Int32) : Tuple(Int32, SegmentKind)
    index = start + 2

    while index < string.bytesize
      byte = string.byte_at(index)

      return {index - start + 1, SegmentKind::Osc} if byte == 0x07 # BEL `\a`

      if byte == 0x1B # CSI ESC `\e`
        next_byte = string.byte_at?(index + 1)
        # ST OSC termination pair
        return {index - start + 2, SegmentKind::Osc} if next_byte == 0x5C # `\`
        # An ESC followed by anything other than `\` starts a new sequence, so the OSC was interrupted.
        # A trailing lone ESC is likely a truncated ST, so mark this as an Escape kind and leave it.
        return {index - start, SegmentKind::Escape} if next_byte
      end

      index += 1
    end
    {string.bytesize - start, SegmentKind::Escape}
  end
end
