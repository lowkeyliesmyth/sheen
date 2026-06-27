require "../foundation"
require "./renderer"

module Sheen
  # A color that resolves to a concrete SGR color through a renderer's profile
  abstract class TerminalColor
    # Resolves to the SGR color for *renderer*'s profile, or nil for no color
    abstract def resolve(renderer : Renderer) : Foundation::SGRColor?
  end

  # The absence of color: default foreground, no background
  class NoColor < TerminalColor
    def resolve(renderer : Renderer) : Foundation::SGRColor?
      nil
    end

    def_equals_and_hash
  end

  # A color from a hex string (eg `#FF0000`) or ANSI256 index string (eg `63`).
  class Color < TerminalColor
    getter value : String

    def initialize(@value : String)
    end

    def resolve(renderer : Renderer) : Foundation::SGRColor?
      Sheen.resolve_value(@value, renderer.color_profile)
    end

    def_equals_and_hash @value
  end

  # A color given by ANSI/256 index (0...255). Extra sugar over `Color`.
  class ANSIColor < TerminalColor
    getter index : Int32

    def initialize(@index : Int32)
    end

    def resolve(renderer : Renderer) : Foundation::SGRColor?
      Sheen.resolve_value(@index.to_s, renderer.color_profile)
    end

    def_equals_and_hash @index
  end

  # A light+dark pair. The renderer's background darkness selects which one gets applied.
  class AdaptiveColor < TerminalColor
    getter light : String
    getter dark : String

    def initialize(@light : String, @dark : String)
    end

    def resolve(renderer : Renderer) : Foundation::SGRColor?
      value = renderer.has_dark_background? ? @dark : @light
      Sheen.resolve_value(value, renderer.color_profile)
    end

    def_equals_and_hash @light, @dark
  end

  # Explicitly defined values per profile, with no automatic degradation between them. Each profile uses its own value as defined, and controls exactly how the color appears at every level of terminal support.
  class CompleteColor < TerminalColor
    # The value used for truecolor 24-bit profiles.
    getter true_color : String
    # The value used for the ANSI256 profile.
    getter ansi256 : String
    # The value used for the basic 16color ANSI profile.
    getter ansi : String

    def initialize(@true_color : String, @ansi256 : String, @ansi : String)
    end

    def resolve(renderer : Renderer) : Foundation::SGRColor?
      profile = renderer.color_profile
      value = case profile
              when .true_color? then @true_color
              when .ansi256?    then @ansi256
              when .ansi?       then @ansi
              else                   return nil
              end
      Sheen.resolve_value(value, profile)
    end

    def_equals_and_hash @true_color, @ansi256, @ansi
  end

  # A light+dark pair of `CompleteColor`'s, selected by background darkness.
  class CompleteAdaptiveColor < TerminalColor
    getter light : CompleteColor
    getter dark : CompleteColor

    def initialize(@light : CompleteColor, @dark : CompleteColor)
    end

    def resolve(renderer : Renderer) : Foundation::SGRColor?
      (renderer.has_dark_background? ? @dark : @light).resolve(renderer)
    end

    def_equals_and_hash @light, @dark
  end

  # Builds a `TerminalColor` from a hex string, an index string, an integer index, or an existing color returned as-is.
  def self.color(value : TerminalColor) : TerminalColor
    value
  end

  # :ditto:
  def self.color(value : String) : TerminalColor
    Color.new(value)
  end

  # :ditto:
  def self.color(value : Int) : TerminalColor
    ANSIColor.new(value.to_i)
  end

  # Helper shared by color types. Resolves a color *value* hex or index string against *profile*.
  #
  # Returns nil for empty/invalid value or a colorless profile.
  def self.resolve_value(value : String, profile : Foundation::Profile) : Foundation::SGRColor?
    return nil if value.empty? || profile.no_tty? || profile.ascii?

    if value.starts_with?("#")
      Foundation.downsample(Foundation::RGB.parse(value), profile)
    else
      index = value.to_i?
      return nil unless index && 0 <= index <= 255
      degrade_index(index, profile)
    end
  rescue ArgumentError
    # An unparseable hex value resolves to no color
    nil
  end

  # Degrades a 0..255 palette *index* to the given color-capable *profile*.
  #
  # Maps indices 0..15 to basic ANSI colors, and higher indices are downsampled to the nearest of the 16 basic colors. No degradation if the *profile* supports the *index*.
  private def self.degrade_index(index : Int32, profile : Foundation::Profile) : Foundation::SGRColor?
    if index < 16
      Foundation::BasicColor.new(index.to_u8)
    elsif profile.ansi?
      Foundation.downsample(Foundation::Palette::ANSI256[index], Foundation::Profile::ANSI)
    else
      Foundation::IndexedColor.new(index.to_u8)
    end
  end

  # The 16 standard ANSI colors.

  BLACK          = ANSIColor.new(0)
  RED            = ANSIColor.new(1)
  GREEN          = ANSIColor.new(2)
  YELLOW         = ANSIColor.new(3)
  BLUE           = ANSIColor.new(4)
  MAGENTA        = ANSIColor.new(5)
  CYAN           = ANSIColor.new(6)
  WHITE          = ANSIColor.new(7)
  BRIGHT_BLACK   = ANSIColor.new(8)
  BRIGHT_RED     = ANSIColor.new(9)
  BRIGHT_GREEN   = ANSIColor.new(10)
  BRIGHT_YELLOW  = ANSIColor.new(11)
  BRIGHT_BLUE    = ANSIColor.new(12)
  BRIGHT_MAGENTA = ANSIColor.new(13)
  BRIGHT_CYAN    = ANSIColor.new(14)
  BRIGHT_WHITE   = ANSIColor.new(15)
end
