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
  def self.set_hyperlink(url : String, **params) : String # ameba:disable Naming/AccessorMethodName
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

  # The decomposed result of parsing one or more SGR seqences. Folding multiple sequences accumulates them.
  #
  # 0 (reset) clears everything seen up to that point.
  record Attributes,
    flags : SGRFlags = SGRFlags::None,
    underline : Underline? = nil,
    fg : SGRColor? = nil,
    bg : SGRColor? = nil,
    reset : Bool = false,
    unknown : Array(String) = [] of String do
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
      when BasicColor
        foreground ? style.foreground_basic(color.index) : style.background_basic(color.index)
      when IndexedColor
        foreground ? style.foreground_indexed(color.index) : style.background_indexed(color.index)
      when RGBColor
        foreground ? style.foreground_rgb(color.r, color.g, color.b) : style.background_rgb(color.r, color.g, color.b)
      when DefaultColor
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
    underline = nil.as(Underline?)
    fg = nil.as(SGRColor?)
    bg = nil.as(SGRColor?)
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

  # Reads an extended color introducer (`38`/`48`) and its sub-parameters.
  #
  # Returns the color plus how many tokens it spans, or `nil` if malformed.
  private def self.consume_extended_color(tokens : Array(String), i : Int32) : Tuple(SGRColor, Int32)?
    case tokens[i + 1]?
    when "5"
      n = tokens[i + 2]?.try(&.to_u8?)
      return nil unless n
      {IndexedColor.new(n).as(SGRColor), 3}
    when "2"
      r = tokens[i + 2]?.try(&.to_u8?)
      g = tokens[i + 3]?.try(&.to_u8?)
      b = tokens[i + 4]?.try(&.to_u8?)
      return nil unless r && g && b
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
end
