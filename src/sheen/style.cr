require "../foundation"
require "./color"
require "./renderer"

module Sheen
  # An immutable set of styling rules bound to a renderer. Every setter returns a new style, and the original is never mutated.
  #
  # Build one fluently like `Style.new.bold.foreground("#7D56F4)` or via the `Sheen.style` block.
  struct Style
    # Generates `initialize` and `copy_with` from a singnlel field list so the two can never drift.
    # Each *decl* is the form `{name, Type, default`.
    #
    # `nil` means unset
    macro storage(*decls)
      def initialize(
        {% for d in decls %}
          @{{d[0].id}} : {{d[1]}} = {{d[2]}},
        {% end %}
      )
      end

      # Returns a copy with the named fields overridden. The rest keep current values.
      #
      # This is the engine behind every setter.
      protected def copy_with(
        {% for d in decls %}
          {{d[0].id}} = @{{d[0].id}},
        {% end %}
      ) : Style
        Style.new(
          {% for d in decls %}
            {{d[0].id}}: {{d[0].id}},
          {% end %}
        )
      end
    end

    # Emits the setters and `?` getter for a boolean property.
    macro bool_prop(name)
      def {{name.id}}(value : Bool = true) : Style
        copy_with({{name.id}}: value)
      end

      def {{name.id}}? : Bool
        @{{name.id}} == true
      end
    end

    # Emits the setter and getter (NoColor when unset) for a color property.
    macro color_prop(name)
      def {{name.id}}(color : TerminalColor | String | Int) : Style
        copy_with({{name.id}}: Sheen.color(color))
      end

      def {{name.id}} : TerminalColor
        @{{name.id}} || NoColor.new
      end
    end

    # Emits the setter and getter for an Int32 property.
    #
    # Defaults to 0 when unset
    macro int_prop(name)
      def {{name.id}}(n : Int32) : Style
        copy_with({{name.id}}: n)
      end

      def {{name.id}} : Int32
        @{{name.id}} || 0
      end
    end

    # The single source of truth for the property fields. `nil` means unset
    storage(
      {renderer, Renderer, Sheen.renderer},
      {value, String, ""},
      {bold, Bool?, nil},
      {italic, Bool?, nil},
      {underline, Bool?, nil},
      {strikethrough, Bool?, nil},
      {reverse, Bool?, nil},
      {blink, Bool?, nil},
      {faint, Bool?, nil},
      {foreground, TerminalColor?, nil},
      {background, TerminalColor?, nil},
      {max_width, Int32?, nil},
      {max_height, Int32?, nil},
    )

    bool_prop bold
    bool_prop italic
    bool_prop underline
    bool_prop strikethrough
    bool_prop reverse
    bool_prop blink
    bool_prop faint

    color_prop foreground
    color_prop background

    int_prop max_width
    int_prop max_height

    # Binds *values* joined by a space, as this style's underlying content.
    def string(*values : String) : Style
      copy_with(value: values.join(' '))
    end

    # The bound content set via `#string`.
    def value : String
      @value
    end

    # Returns the renderer this style is bound to.
    def renderer : Renderer
      @renderer
    end

    # Rebinds this style to *r*, is chainable.
    def renderer(r : Renderer) : Style
      copy_with(renderer: r)
    end

    # Renders *strings* through this style's rules, each line is styled independently:
    # - joined by a space
    # - prefixed with any bound `#string` content
    # - wrapped in SGR sequences assembled from current properties
    # - with colors resolved and downsampled through the attached renderer's profile
    # - width and heigh truncation is applied last
    def render(*strings : String) : String
      render_parts(strings.to_a)
    end

    # Renders the bound `#string` content.
    def to_s(io : IO) : Nil
      io << render_parts([] of String)
    end

    # Shared render path: prepends bound content, joins, styles, and limits.
    private def render_parts(strings : Array(String)) : String
      parts = strings.dup
      parts.unshift(@value) unless @value.empty?
      content = parts.join(' ')

      content = apply_sequence(sgr_sequence, content)
      limit_height(limit_width(content))
    end

    # Builds the opening SGR sequence for this style's rules, or "" if none emit.
    private def sgr_sequence : String
      builder = Foundation::Style.new
      builder.bold if bold?
      builder.faint if faint?
      builder.italic if italic?
      builder.underline if underline?
      builder.reverse if reverse?
      builder.blink if blink?
      builder.strikethrough if strikethrough?

      if fg = @foreground.try &.resolve(@renderer)
        apply_color(builder, fg, foreground: true)
      end
      if bg = @background.try &.resolve(@renderer)
        apply_color(builder, bg, foreground: false)
      end

      builder.to_s
    end

    # Applies an already-resolved SGR *color& to *builder* as fg or bg.
    private def apply_color(builder : Foundation::Style, color : Foundation::SGRColor, *, foreground : Bool) : Nil
      case color
      in Foundation::BasicColor
        foreground ? builder.foreground_basic(color.index) : builder.background_basic(color.index)
      in Foundation::IndexedColor
        foreground ? builder.foreground_indexed(color.index) : builder.background_indexed(color.index)
      in Foundation::RGBColor
        foreground ? builder.foreground_rgb(color.r, color.g, color.b) : builder.background_rgb(color.r, color.g, color.b)
      in Foundation::DefaultColor
        foreground ? builder.default_foreground : builder.default_background
      end
    end

    # Wraps each line of *content* with *seq* and a reset, so styling resets at each newline.
    #
    # Returns content unchanged when *seq* is empty.
    private def apply_sequence(seq : String, content : String) : String
      return content if seq.empty?

      String.build do |io|
        lines = content.split('\n')
        lines.each_with_index do |line, i|
          io << seq << line << Foundation::RESET_STYLE
          io << '\n' if i < lines.size - 1
        end
      end
    end

    # Truncates each line of *content* to `max_width` visible cells. Returns content unchanged when `max_width` is unset.
    private def limit_width(content : String) : String
      width = @max_width
      return content unless width && width > 0
      content.split('\n').map { |line| Foundation.truncate(line, width) }.join('\n')
    end

    # Keeps only the first `max_height` lines. Returns content unchanged when `limit_height` is unset.
    private def limit_height(content : String) : String
      height = @max_height
      return content unless height && height > 0
      content.split('\n').first(height).join('\n')
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
