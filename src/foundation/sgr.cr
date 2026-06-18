module Foundation
  # Control Sequence Introducer
  CSI         = "\e["
  RESET_STYLE = "\e[0m"

  # SGR underline styles. Sub-styles use the subparameter of SGR 4 (eg "4:3" for curly).
  # Reset via SGR 24 covers all substyles.
  enum Underline
    None   = 0
    Single = 1
    Double = 2
    Curly  = 3
    Dotted = 4
    Dashed = 5
  end

  # Build a Select Graphic Rendition (SGR) escape sequence by accumulating parameters.
  # Mutating is chainable, each method appends and returns self.
  class Style # Class not struct here. Why? Structs copy on every method call, which breaks chainable mutation.

    # Create an empty builder with no parameters set.
    def initialize
      @params = [] of String
    end

    # Enable bold (SGR 1)
    def bold : self
      @params << "1"
      self
    end

    # Enable faint/dim (SGR 2)
    def faint : self
      @params << "2"
      self
    end

    # Enable italic (SGR 3)
    def italic : self
      @params << "3"
      self
    end

    # Enable single underline (SGR 4)
    def underline : self
      @params << "4"
      self
    end

    # Enable underline of given substyle (SGR 4:n)
    def underline_style(style : Underline) : self
      @params << "4:#{style.value}"
      self
    end

    # Enable blink (SGR 5)
    def blink : self
      @params << "5"
      self
    end

    # Enable reverse which swaps fg and bg (SGR 7)
    def reverse : self
      @params << "7"
      self
    end

    # Enable strikethrough (SGR 9)
    def strikethrough : self
      @params << "9"
      self
    end

    # Set a basic fg color by index 0..15 (SGR 30-37 / 90-97 bright).
    #
    # Raises if *index* > 15
    def foreground_basic(index : UInt8) : self
      raise ArgumentError.new("basic color index must be 0..15") if index > 15
      code = index < 8 ? 30 + index : 90 + (index - 8)
      @params << code.to_s
      self
    end

    # Sets a 256-color fg by palette index (SGR 38;5;*index*)
    def foreground_indexed(index : UInt8) : self
      @params << "38;5;#{index}"
      self
    end

    # Sets a truecolor fg (SGR 38;2;*r*;*g*;*b*)
    def foreground_rgb(r : UInt8, g : UInt8, b : UInt8) : self
      @params << "38;2;#{r};#{g};#{b}"
      self
    end

    # Resets fg to terminal default (SGR 39)
    def default_foreground : self
      @params << "39"
      self
    end

    # Set a basic bg color by index 0..15 (SGR 40-37 / 100-107 bright).
    #
    # Raises if *index* > 15
    def background_basic(index : UInt8) : self
      raise ArgumentError.new("basic color index must be 0..15") if index > 15
      code = index < 8 ? 40 + index : 100 + (index - 8)
      @params << code.to_s
      self
    end

    # Sets a 256-color bg by palette index (SGR 48;5;*index*)
    def background_indexed(index : UInt8) : self
      @params << "48;5;#{index}"
      self
    end

    # Sets a truecolor bg (SGR 48;2;*r*;*g*;*b*)
    def background_rgb(r, g, b : UInt8) : self
      @params << "48;2;#{r};#{g};#{b}"
      self
    end

    # Resets the bg to terminal default (SGR 49)
    def default_background : self
      @params << "49"
      self
    end

    # Appends a raw SGR parameter as-is, for params that the typed setters don't model.
    def raw(param : String) : self
      @params << param
      self
    end

    # Resets all attributes (SGR 0)
    def reset : self
      @params << "0"
      self
    end

    # Renders the accumulated params as a `CSI ... m` sequence.
    # Or nothing if no params are set.
    def to_s(io : IO) : Nil
      return if @params.empty?
      io << CSI
      @params.join(io, ';')
      io << 'm'
    end
  end
end
