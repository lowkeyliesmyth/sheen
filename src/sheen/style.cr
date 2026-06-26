require "../foundation"
require "./color"
require "./renderer"

module Sheen
  # An immutable set of styling rules bound to a renderer. Every setter returns a new style, and the original is never mutated.
  #
  # Build one fluently like `Style.new.bold.foreground("#7D56F4)` or via the `Sheen.style` block.
  class Style
    # The properties a Style can carry. Used as two bitsets:
    #
    # - `@props`: which properties are explicitly set
    # - `@attrs`: the on/off value for boolean properties
    #
    #  This distinction lets the style know the difference between “Bold was never specified” and “Bold was explicitly turned off”.
    @[Flags]
    enum Prop
      Bold
      Italic
      Underline
      Strikethrough
      Reverse
      Blink
      Faint
      Foreground
      Background
      MaxWidth
      MaxHeight
    end

    @props : Prop = Prop::None # which properties are explicitly set
    @attrs : Prop = Prop::None # on/off values for bool properties
    @value : String = ""
    @foreground : TerminalColor? = nil
    @background : TerminalColor? = nil
    @max_width : Int32 = 0
    @max_height : Int32 = 0
    @renderer : Renderer

    # Creates an empty Style bound to *renderer* (uses the package default unless provided here).
    def initialize(@renderer : Renderer = Sheen.renderer, value : String = "")
      @value = value
    end

    # Enables/disables bold rendering. Returns a new Style.
    def bold(value : Bool = true) : Style
      dup.tap &.flag(Prop::Bold, value)
    end

    # Enables/disables faint rendering. Returns a new Style.
    def faint(value : Bool = true) : Style
      dup.tap &.flag(Prop::Faint, value)
    end

    # Enables/disables italic rendering. Returns a new Style.
    def italic(value : Bool = true) : Style
      dup.tap &.flag(Prop::Italic, value)
    end

    # Enables/disables underline rendering. Returns a new Style.
    def underline(value : Bool = true) : Style
      dup.tap &.flag(Prop::Underline, value)
    end

    # Enables/disables strikethrough rendering. Returns a new Style.
    def strikethrough(value : Bool = true) : Style
      dup.tap &.flag(Prop::Strikethrough, value)
    end

    # Enables/disables reverse rendering, swapping bg+fg. Returns a new Style.
    def reverse(value : Bool = true) : Style
      dup.tap &.flag(Prop::Reverse, value)
    end

    # Enables/disables blinking rendering. Returns a new Style.
    def blink(value : Bool = true) : Style
      dup.tap &.flag(Prop::Blink, value)
    end

    # Sets the foreground color, accepting any value `Sheen.color` accepts.
    def foreground(color : TerminalColor | String | Int) : Style
      dup.tap &.assign_foreground(Sheen.color(color))
    end

    # Sets the background color, accepting any value `Sheen.color` accepts.
    def background(color : TerminalColor | String | Int) : Style
      dup.tap &.assign_background(Sheen.color(color))
    end

    # Limits the rendered block to *n* visible cells wide, truncating per line.
    def max_width(n : Int32) : Style
      dup.tap &.assign_max_width(n)
    end

    # Limits the rendered block to *n* lines tall.
    def max_height(n : Int32) : Style
      dup.tap &.assign_max_height(n)
    end

    # Binds *values* as this style's underlying content. Joins *values* by a space.
    def string(*values : String) : Style
      dup.tap &.assign_value(values.join(' '))
    end

    # Returns the renderer this style is bound to.
    def renderer : Renderer
      @renderer
    end

    # Rebinds this style to *r*. Chainable.
    def renderer(r : Renderer) : Style
      dup.tap &.assign_renderer(r)
    end

    def bold? : Bool
      on?(Prop::Bold)
    end

    def faint? : Bool
      on?(Prop::Faint)
    end

    def italic? : Bool
      on?(Prop::Italic)
    end

    def underline? : Bool
      on?(Prop::Underline)
    end

    def strikethrough? : Bool
      on?(Prop::Strikethrough)
    end

    def reverse? : Bool
      on?(Prop::Reverse)
    end

    def blink? : Bool
      on?(Prop::Blink)
    end

    # The foreground color, or `NoColor` when unset.
    def foreground : TerminalColor
      @foreground || NoColor.new
    end

    # The background color, or `NoColor` when unset.
    def background : TerminalColor
      @background || NoColor.new
    end

    # The maximum width in cells. Defaults to 0 when unset.
    def max_width : Int32
      @max_width
    end

    # The maximum height in lines. Defaults to 0 when unset.
    def max_height : Int32
      @max_height
    end

    # The bound content set via `#string`.
    def value : String
      @value
    end

    # Whether property *key* is explicitly set or not.
    def set?(key : Prop) : Bool
      @props.includes?(key)
    end

    # Marks *key* as explicitly set and records its on/off value.
    protected def flag(key : Prop, value : Bool) : Nil
      @props = @props | key
      @attrs = value ? (@attrs | key) : (@attrs & ~key)
    end

    # Marks foreground as explicitly set and sets its color.
    protected def assign_foreground(color : TerminalColor) : Nil
      @props = @props | Prop::Foreground
      @foreground = color
    end

    # Marks background as explicitly set and sets its color.
    protected def assign_background(color : TerminalColor) : Nil
      @props = @props | Prop::Background
      @background = color
    end

    # Marks max width as explicitly set and sets its value.
    protected def assign_max_width(n : Int32) : Nil
      @props = @props | Prop::MaxWidth
      @max_width = n
    end

    # Marks max height as explicitly set and sets its value.
    protected def assign_max_height(n : Int32) : Nil
      @props = @props | Prop::MaxHeight
      @max_height = n
    end

    # Sets *value* as the style's underlying content, rendered when the Style is stringified.
    protected def assign_value(value : String) : Nil
      @value = value
    end

    # Sets *r* as the renderer this style is bound to.
    protected def assign_renderer(r : Renderer) : Nil
      @renderer = r
    end

    # Checks whether a bool property *key* is set and on
    private def on?(key : Prop) : Bool
      @attrs.includes?(key)
    end

    # A mutable scratch object yielded by `Sheen.style`.
    # Forwards every setter to the wrapped immutable Style and accumulates the result, so block-style config reads imperatively while the Style stays immutable under the covers.
    class Builder
      # The accumulated Style so far.
      getter style : Style

      def initialize(renderer : Renderer)
        @style = Style.new(renderer)
      end

      # Forward any setter call to the wrapped Style, storing the new Style.
      macro method_missing(call)
        @style = @style.{{call}}
        self
      end
    end
  end

  # Builds a Style imperatively. Yields a mutable builder and returns the resulting immutable Style.
  #
  # `Sheen.style { |s| s.bold; s.foreground("#FF0000") }`.
  def self.style(renderer : Renderer = Sheen.renderer, & : Style::Builder ->) : Style
    builder = Style::Builder.new(renderer)
    yield builder
    builder.style
  end
end
