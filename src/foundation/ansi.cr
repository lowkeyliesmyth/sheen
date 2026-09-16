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

  # SGR basic color: index 0..15
  record BasicColor, index : UInt8 # 0..15 -> 30-37/90-97, 40-47/100-107
  # SGR 256-color palette index: 0..255
  record IndexedColor, index : UInt8 # 0..255 -> 38;5;n / 48;5;n
  # SGR truecolor value
  record RGBColor, r : UInt8, g : UInt8, b : UInt8 # -> 38;2;r;g;b / 48;2;r;g;b

  # The terminal default fg/bg (SGR 39 / 49)
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

  # The decomposed result of parsing one or more SGR sequences. Folding multiple sequences accumulates them.
  #
  # 0 (reset) clears everything seen up to that point.
  record Attributes,
    flags : SGRFlags = SGRFlags::None,
    underline : Underline? = nil,
    fg : SGRColor? = nil,
    bg : SGRColor? = nil,
    reset : Bool = false,
    unknown : Array(String) = [] of String

  # Meta: Reopened so these methods live outside the `record` macro block but are still attached to the same struct.
  # Why do this? Because the `crystal docs` commands' `wants_doc`  parser chokes on method docstring comments under the `record` macro.
  struct Attributes
    # Serializes the attributes to an SGR escape sequence and writes it to *io*.
    # Applies accumulated state in order.
    #
    # Round-trip is semantically accurate, not byte-accurate.
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

    # Emits an SGR color sequence for *color* to *style*, targeting foreground or background based on *foreground*.
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

  # Parses every SGR sequence found in *string* and folds them into one `Attributes`.
  # Text, OSC, and non-SGR escapes are ignored, and malformed input never raises.
  # TODO: Refactor, this is crazy complex fr fr
  def self.parse_sgr(string : String) : Attributes # ameba:disable Metrics/CyclomaticComplexity
    flags = SGRFlags::None
    underline : Underline? = nil
    fg : SGRColor? = nil
    bg : SGRColor? = nil
    reset = false
    unknown = [] of String

    string.scan(SGR_PATTERN) do |match|
      tokens = match[1].split(';')

      i = 0
      while i < tokens.size
        tok = tokens[i]
        step = 1
        case tok
        when "", "0"
          reset = true
          flags = SGRFlags::None
          underline = nil
          fg = nil
          bg = nil
          unknown.clear
        when "1"  then flags |= SGRFlags::Bold # bitwise OR assignment operator
        when "2"  then flags |= SGRFlags::Faint
        when "3"  then flags |= SGRFlags::Italic
        when "5"  then flags |= SGRFlags::Blink
        when "7"  then flags |= SGRFlags::Reverse
        when "9"  then flags |= SGRFlags::Strikethrough
        when "22" then flags &= ~(SGRFlags::Bold | SGRFlags::Faint) # Bitwise AND assignment and NOT operator
        when "23" then flags &= ~SGRFlags::Italic
        when "24" then underline = nil
        when "25" then flags &= ~SGRFlags::Blink
        when "27" then flags &= ~SGRFlags::Reverse
        when "29" then flags &= ~SGRFlags::Strikethrough
        when "39" then fg = DefaultColor.new
        when "49" then bg = DefaultColor.new
        when "38"
          if res = consume_extended_color(tokens, i)
            fg, step = res
          else
            unknown << tok
          end
        when "48"
          if res = consume_extended_color(tokens, i)
            bg, step = res
          else
            unknown << tok
          end
        else
          if tok == "4"
            underline = Underline::Single
          elsif tok.starts_with?("4:")
            sub = tok[2..].to_i?
            u = sub ? Underline.from_value?(sub) : nil
            if u
              underline = u
            else
              unknown << tok
            end
          elsif (code = tok.to_i?) && (basic = basic_color(code))
            color, is_fg = basic
            is_fg ? (fg = color) : (bg = color)
          else
            unknown << tok
          end
        end
        i += step
      end
    end

    Attributes.new(flags, underline, fg, bg, reset, unknown)
  end

  # Parses the extended color sequence (`38`/`48`) starting at *tokens[i]*, reading its `5;n` (indexed) or `2;r;g;b` (RGB) sub-parameters.
  #
  # Returns a tuple of the parsed `SGRColor` and the number of tokens consumed (including the introducer), or `nil` if the sub-parameters are missing or malformed.

  private def self.consume_extended_color(tokens : Array(String), i : Int32) : Tuple(SGRColor, Int32)?
    case tokens[i + 1]?
    when "5"
      n = tokens[i + 2]?.try(&.to_u8?)
      return unless n
      {IndexedColor.new(n).as(SGRColor), 3}
    when "2"
      r = tokens[i + 2]?.try(&.to_u8?)
      g = tokens[i + 3]?.try(&.to_u8?)
      b = tokens[i + 4]?.try(&.to_u8?)
      return unless r && g && b
      {RGBColor.new(r, g, b).as(SGRColor), 5}
    end
  end

  # Maps a basic SGR color *code* to its returned *SGRColor* index and *Bool* of whether it is foreground or not.
  private def self.basic_color(code : Int32) : Tuple(SGRColor, Bool)?
    case code
    when 30..37
      {BasicColor.new((code - 30).to_u8).as(SGRColor), true}
    when 90..97
      {BasicColor.new((code - 90 + 8).to_u8).as(SGRColor), true}
    when 40..47
      {BasicColor.new((code - 40).to_u8).as(SGRColor), false}
    when 100..107
      {BasicColor.new((code - 100 + 8).to_u8).as(SGRColor), false}
    end
  end

  # The classification of a segment yielded by the `each_segment` method
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
