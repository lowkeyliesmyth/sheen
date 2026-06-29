require "../foundation"
require "./color"
require "./position"
require "./renderer"

module Sheen
  # An immutable set of styling rules bound to a renderer. Every setter returns a new style, and the original is never mutated.
  #
  # Build one fluently like `Style.new.bold.foreground("#7D56F4)` or via the `Sheen.style` block.
  struct Style
    # Default tab expansion width when `tab_width` is unset.
    TAB_WIDTH_DEFAULT = 4

    # Sentinel for `#tab_width` that disables tab conversion wholesale.
    NO_TAB_CONVERSION = -1

    # Generates `initialize` and `copy_with` from a single field list so the two can never drift.
    # Each *decl* is the form `{name, Type, default}`.
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
      # Enables or disables {{name.id}}.
      # Returns a new Style
      def {{name.id}}(value : Bool = true) : Style
        copy_with({{name.id}}: value)
      end

      # True when {{name.id}} is enabled.
      def {{name.id}}? : Bool
        @{{name.id}} == true
      end

      # True when {{name.id}} has been explicitly set.
      def {{name.id}}_set? : Bool
        !@{{name.id}}.nil?
      end
    end

    # Emits the setter and getter for a color property.
    #
    # Defaults to NoColor when unset.
    macro color_prop(name)
      # Sets {{name.id}} from a `TerminalColor`, hex string, or ANSI index.
      # Returns a new Style
      def {{name.id}}(color : TerminalColor | String | Int) : Style
        copy_with({{name.id}}: Sheen.color(color))
      end

      # The {{name.id}} color, or `NoColor` when unset.
      def {{name.id}} : TerminalColor
        @{{name.id}} || NoColor.new
      end

      # True when {{name.id}} has been explicitly set.
      def {{name.id}}_set? : Bool
        !@{{name.id}}.nil?
      end
    end

    # Emits the setter and getter for an Int32 property.
    #
    # Defaults to 0 when unset
    macro int_prop(name)
      # Sets {{name.id}} to *n*.
      # Returns a new Style
      def {{name.id}}(n : Int32) : Style
        copy_with({{name.id}}: n)
      end

      # The {{name.id}} value, or 0 when unset.
      def {{name.id}} : Int32
        @{{name.id}} || 0
      end

      # True when {{name.id}} has been explicitly set.
      def {{name.id}}_set? : Bool
        !@{{name.id}}.nil?
      end
    end

    # Emits the setter and getter for a Position property.
    #
    # *default* when unset.
    macro position_prop(name, default)
      # Sets {{name.id}} to *pos*.
      # Returns a new Style.
      def {{name.id}}(pos : Position) : Style
        copy_with({{name.id}}: pos)
      end

      # The {{name.id}} position, or `{{default}}` when unset.
      def {{name.id}} : Position
        @{{name.id}} || {{default}}
      end

      # True when {{name.id}} has been explicitly set.
      def {{name.id}}_set? : Bool
        !@{{name.id}}.nil?
      end
    end

    # The single source of truth for the property fields. `nil` means unset.
    #
    # Follows the form `{name, Type, default}`
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
      {width, Int32?, nil},
      {height, Int32?, nil},
      {align_horizontal, Position?, nil},
      {align_vertical, Position?, nil},
      {padding_top, Int32?, nil},
      {padding_right, Int32?, nil},
      {padding_bottom, Int32?, nil},
      {padding_left, Int32?, nil},
      {margin_top, Int32?, nil},
      {margin_right, Int32?, nil},
      {margin_bottom, Int32?, nil},
      {margin_left, Int32?, nil},
      {margin_background, TerminalColor?, nil},
      {inline, Bool?, nil},
      {tab_width, Int32?, nil},
    )

    bool_prop bold
    bool_prop italic
    bool_prop underline
    bool_prop strikethrough
    bool_prop reverse
    bool_prop blink
    bool_prop faint
    bool_prop inline

    color_prop foreground
    color_prop background
    color_prop margin_background

    int_prop max_width
    int_prop max_height
    int_prop width
    int_prop height
    int_prop padding_top
    int_prop padding_right
    int_prop padding_bottom
    int_prop padding_left
    int_prop margin_top
    int_prop margin_right
    int_prop margin_bottom
    int_prop margin_left

    position_prop align_horizontal, Position::LEFT
    position_prop align_vertical, Position::TOP

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

    # Sets padding via CSS shorthand:
    # - 1 *value*: all sides
    # - 2 *values*: vert, horiz
    # - 3 *values*: top, horiz, bottom
    # - 4 *values*: top, right, bottom, left
    #
    # Raises on any other *value* count.
    def padding(*values : Int32) : Style
      top, right, bottom, left = expand_sides(values.to_a)
      copy_with(padding_top: top, padding_right: right, padding_bottom: bottom, padding_left: left)
    end

    # Sets margins via same CSS shorthand as `#padding`.
    #
    # Raises on any *value* count other than 1-4.
    def margin(*values : Int32) : Style
      top, right, bottom, left = expand_sides(values.to_a)
      copy_with(margin_top: top, margin_right: right, margin_bottom: bottom, margin_left: left)
    end

    # Sets *horizontal* alignment, with optional *vertical* alignment.
    def align(horizontal : Position, vertical : Position? = nil) : Style
      if vertical
        copy_with(align_horizontal: horizontal, align_vertical: vertical)
      else
        copy_with(align_horizontal: horizontal)
      end
    end

    # Tab expansion width setter.
    # Use `NO_TAB_CONVERSION` to leave tabs intact.
    def tab_width(n : Int32) : Style
      copy_with(tab_width: n)
    end

    # Tab expansion width getter.
    # Uses TAB_WIDTH_DEFAULT if not otherwise set.
    def tab_width : Int32
      @tab_width || TAB_WIDTH_DEFAULT
    end

    # Total horizontal padding,  left + right
    def horizontal_padding : Int32
      padding_left + padding_right
    end

    # Total vertical padding, top + bottom
    def vertical_padding : Int32
      padding_top + padding_bottom
    end

    # Total horizontal margins, left + right
    def horizontal_margins : Int32
      margin_left + margin_right
    end

    # Total vertical margins, top + bottom
    def vertical_margins : Int32
      margin_top + margin_bottom
    end

    # Total horizontal border width.
    # TODO, 0 placeholder until then.
    def horizontal_border_size : Int32
      0
    end

    # Total vertical border width.
    # TODO, 0 placeholder until then.
    def vertical_border_size : Int32
      0
    end

    # Getter sum of horizontal margins, padding, and border.
    def horizontal_frame_size : Int32
      horizontal_margins + horizontal_padding + horizontal_border_size
    end

    # Getter sum of vertical margins, padding, and border.
    def vertical_frame_size : Int32
      vertical_margins + vertical_padding + vertical_border_size
    end

    # Getter for the {horizontal, vertical} frame size
    def frame_size : {Int32, Int32}
      {horizontal_frame_size, vertical_frame_size}
    end

    # Expands CSS-shorthand *values* to `{top, right, bottom, left}`.
    #
    # Raises ArgumentError if *values*.size count is not 1-4.
    private def expand_sides(values : Array(Int32)) : {Int32, Int32, Int32, Int32}?
      case values.size
      when 1 then {values[0], values[0], values[0], values[0]}
      when 2 then {values[0], values[1], values[0], values[1]}
      when 3 then {values[0], values[1], values[2], values[1]}
      when 4 then {values[0], values[1], values[2], values[3]}
      else        raise ArgumentError.new("padding/margin accepts 1-4 values, got #{values.size}")
      end
    end

    # Shared render path that joins bound content *strings*, normalizes, styles, and applies widdth/heigh limits to them.
    private def render_parts(strings : Array(String)) : String
      parts = strings.dup
      parts.unshift(@value) unless @value.empty?
      content = parts.join(' ')

      # pre-styling normalization order: tabs -> CRLF -> inline -> wrap
      content = expand_tabs(content)
      content = content.gsub("\r\n", "\n")
      content = content.delete('\n') if inline?
      if !inline? && (w = @width) && w > 0
        content = Foundation.wrap(content, w - horizontal_padding, "")
      end

      content = apply_sequence(sgr_sequence, content)
      limit_height(limit_width(content))
    end

    # Expands tab per `tab_width`, applied even when no style rules are set
    #
    # - NO_TAB_CONVERSION: leaves tabs intact
    # - 0: strips tabs
    # - anything else: replaces each tab with that many spaces
    private def expand_tabs(content : String) : String
      width = tab_width
      case width
      when NO_TAB_CONVERSION then content
      when 0                 then content.delete('\t')
      else                        content.gsub('\t', " " * width)
      end
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
