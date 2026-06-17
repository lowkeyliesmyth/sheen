module Sheen
  module ANSI
    # Control Sequence Introducer
    CSI         = "\e["
    RESET_STYLE = "\e[0m"
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

    # Build a Select Graphic Rendition (SGR) escape sequence by accumulating parameters.
    # Mutating is chainable, each method appends and returns self.
    class Style
      # Class not struct here. Why? Structs copy on every method call, which breaks chainable mutation.
      def initialize
        @params = [] of String
      end

      def bold : self
        @params << "1"
        self
      end

      def faint : self
        @params << "2"
        self
      end

      def italic : self
        @params << "3"
        self
      end

      def underline : self
        @params << "4"
        self
      end

      def blink : self
        @params << "5"
        self
      end

      def reverse : self
        @params << "7"
        self
      end

      def strikethrough : self
        @params << "9"
        self
      end

      # 0-15. 0-7 standard (30-37), 8-15 bright (90-97)
      #
      #  Converts a 0–15 color index into the correct ANSI code number for coloring foreground terminal text.
      def foreground_basic(index : UInt8) : self
        raise ArgumentError.new("basic color index must be 0..15") if index > 15
        code = index < 8 ? 30 + index : 90 + (index - 8)
        @params << code.to_s
        self
      end

      def foreground_indexed(index : UInt8) : self
        @params << "38;5;#{index}"
        self
      end

      def foreground_rgb(r : UInt8, g : UInt8, b : UInt8) : self
        @params << "38;2;#{r};#{g};#{b}"
        self
      end

      def default_foreground : self
        @params << "39"
        self
      end

      # 0-15. 0-7 standard (40-47), 8-15 bright (100-107)
      #
      #  Converts a 0–15 color index into the correct ANSI code number for coloring background terminal text.
      def background_basic(index : UInt8) : self
        raise ArgumentError.new("basic color index must be 0..15") if index > 15
        code = index < 8 ? 40 + index : 100 + (index - 8)
        @params << code.to_s
        self
      end

      def background_indexed(index : UInt8) : self
        @params << "48;5;#{index}"
        self
      end

      def background_rgb(r, g, b : UInt8) : self
        @params << "48;2;#{r};#{g};#{b}"
        self
      end

      def default_background : self
        @params << "49"
        self
      end

      def reset : self
        @params << "0"
        self
      end

      # Render as escape sequence, or empty string if no params
      def to_s(io : IO) : Nil
        return if @params.empty?
        io << CSI
        @params.join(io, ';')
        io << 'm'
      end
    end
  end
end
