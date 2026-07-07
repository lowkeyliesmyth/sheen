require "../foundation"
require "./border"
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

      # Returns a new Style with {{name.id}} returned to the unset (inheritable) state.
      def unset_{{name.id}} : Style
        copy_with({{name.id}}: nil)
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

      # Returns a new Style with {{name.id}} returned to the unset (inheritable) state.
      def unset_{{name.id}} : Style
        copy_with({{name.id}}: nil)
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

      # Returns a new Style with {{name.id}} returned to the unset (inheritable) state.
      def unset_{{name.id}} : Style
        copy_with({{name.id}}: nil)
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

      # Returns a new Style with {{name.id}} returned to the unset (inheritable) state.
      def unset_{{name.id}} : Style
        copy_with({{name.id}}: nil)
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
      {border_style, Border?, nil},
      {border_top, Bool?, nil},
      {border_right, Bool?, nil},
      {border_bottom, Bool?, nil},
      {border_left, Bool?, nil},
      {border_top_foreground, TerminalColor?, nil},
      {border_right_foreground, TerminalColor?, nil},
      {border_bottom_foreground, TerminalColor?, nil},
      {border_left_foreground, TerminalColor?, nil},
      {border_top_background, TerminalColor?, nil},
      {border_right_background, TerminalColor?, nil},
      {border_bottom_background, TerminalColor?, nil},
      {border_left_background, TerminalColor?, nil},
    )

    bool_prop bold
    bool_prop italic
    bool_prop underline
    bool_prop strikethrough
    bool_prop reverse
    bool_prop blink
    bool_prop faint
    bool_prop inline
    bool_prop border_top
    bool_prop border_right
    bool_prop border_bottom
    bool_prop border_left

    color_prop foreground
    color_prop background
    color_prop margin_background
    color_prop border_top_foreground
    color_prop border_right_foreground
    color_prop border_bottom_foreground
    color_prop border_left_foreground
    color_prop border_top_background
    color_prop border_right_background
    color_prop border_bottom_background
    color_prop border_left_background

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

    # Overlays *other* onto this style.
    # For every property *other* has explicitly set that this style has not, this style adopts the value of *other* and returns a new Style.
    #
    # Note:
    # - Inheriting a background also seeds the margin background when neither style has one set.
    # - Padding, margins, and the bound string value are the exceptions and are **never** inherited.
    def inherit(other : Style) : Style
      inherited = self
      {% for name in [
                       "bold",
                       "italic",
                       "underline",
                       "strikethrough",
                       "reverse",
                       "blink",
                       "faint",
                       "foreground",
                       "background",
                       "max_width",
                       "max_height",
                       "width",
                       "height",
                       "align_horizontal",
                       "align_vertical",
                       "margin_background",
                       "inline",
                       "tab_width",
                       "border_style",
                       "border_top",
                       "border_right",
                       "border_bottom",
                       "border_left",
                       "border_top_foreground",
                       "border_right_foreground",
                       "border_bottom_foreground",
                       "border_left_foreground",
                       "border_top_background",
                       "border_right_background",
                       "border_bottom_background",
                       "border_left_background",
                     ] %}
    inherited = inherited.copy_with({{name.id}}: other.@{{name.id}}) if @{{name.id}}.nil?
        {% end %}

      # A background also seeds the margin background, but only if neither style sets one.
      if !other.@background.nil? && @margin_background.nil? && other.@margin_background.nil?
        inherited = inherited.copy_with(margin_background: other.@background)
      end

      inherited
    end

    # Binds *values* joined by a space, as this style's underlying content.
    def string(*values : String) : Style
      copy_with(value: values.join(' '))
    end

    # Returns a new Style with the bound string value cleared
    def unset_string : Style
      copy_with(value: "")
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
      StylePainter.new(self).render(strings.to_a)
    end

    # Renders the bound `#string` content.
    def to_s(io : IO) : Nil
      io << StylePainter.new(self).render([] of String)
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

    # Returns a new Style with all four padding sides unset.
    def unset_padding : Style
      copy_with(padding_top: nil,
        padding_right: nil,
        padding_bottom: nil,
        padding_left: nil)
    end

    # Sets margins via same CSS shorthand as `#padding`.
    #
    # Raises on any *value* count other than 1-4.
    def margin(*values : Int32) : Style
      top, right, bottom, left = expand_sides(values.to_a)
      copy_with(margin_top: top, margin_right: right, margin_bottom: bottom, margin_left: left)
    end

    # Returns a new Style with all four margin sides unset
    def unset_margins : Style
      copy_with(margin_top: nil,
        margin_right: nil,
        margin_bottom: nil,
        margin_left: nil)
    end

    # Sets *horizontal* alignment, with optional *vertical* alignment.
    def align(horizontal : Position, vertical : Position? = nil) : Style
      if vertical
        copy_with(align_horizontal: horizontal, align_vertical: vertical)
      else
        copy_with(align_horizontal: horizontal)
      end
    end

    # Returns a new Style with both alignment axes unset
    def unset_align : Style
      copy_with(align_horizontal: nil, align_vertical: nil)
    end

    # Sets the border *b* character styleset without touching side visibility. If no side is later toggled, all four are rendered. (see `#implicit_borders?`)
    def border_style(b : Border) : Style
      copy_with(border_style: b)
    end

    # The border character set, or a `none` border when unset.
    def border_style : Border
      @border_style || Border.new
    end

    # True when a border style has been explicitly set.
    def border_style_set? : Bool
      !@border_style.nil?
    end

    # Returns a new Style with the border style removed.
    def unset_border_style : Style
      copy_with(border_style: nil)
    end

    # Sets the border *b* and which sides show, via CSS-style shorthand.
    # - no *side* values: shows all four
    # - 1 *side* value: all sides
    # - 2 *side* values: vert, horiz
    # - 3 *side* values: top, horiz, bottom
    # - 4 *side* values: top, right, bottom, left
    def border(b : Border, *sides : Bool) : Style
      top, right, bottom, left = which_sides_bool(sides.to_a)
      copy_with(
        border_style: b,
        border_top: top, border_right: right, border_bottom: bottom, border_left: left,
      )
    end

    # :ditto:
    def border(b : Border) : Style
      copy_with(
        border_style: b,
        border_top: true, border_right: true, border_bottom: true, border_left: true,
      )
    end

    # Sets all four border foreground *colors* via CSS 1-4 shorthand values.
    # Raises on a value count outside 1-4.
    def border_foreground(*colors : TerminalColor | String | Int) : Style
      top, right, bottom, left = expand_sides(colors.to_a.map { |clr| Sheen.color(clr) })
      copy_with(
        border_top_foreground: top,
        border_right_foreground: right,
        border_bottom_foreground: bottom,
        border_left_foreground: left,
      )
    end

    # Returns a new Style with all four border foreground colors unset.
    def unset_border_foreground : Style
      copy_with(
        border_top_foreground: nil,
        border_right_foreground: nil,
        border_bottom_foreground: nil,
        border_left_foreground: nil,
      )
    end

    # Sets all four border background colors via CSS 1-4 shorthand values.
    # Raises on a value count outside 1-4.
    def border_background(*colors : TerminalColor | String | Int) : Style
      top, right, bottom, left = expand_sides(colors.to_a.map { |clr| Sheen.color(clr) })
      copy_with(
        border_top_background: top,
        border_right_background: right,
        border_bottom_background: bottom,
        border_left_background: left,
      )
    end

    # Returns a new Style with all four border background colors unset.
    def unset_border_background : Style
      copy_with(border_top_background: nil,
        border_right_background: nil,
        border_bottom_background: nil,
        border_left_background: nil)
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

    # Returns a new STyle with the tab width returned to its default.
    def unset_tab_width : Style
      copy_with(tab_width: nil)
    end

    # True when a border style is set but no side has been explicitly toggled, which triggers all four sides to render
    def implicit_borders? : Bool
      !border_style.none? && !(border_top_set? || border_right_set? || border_bottom_set? || border_left_set?)
    end

    # Cell-width of the top border edge.
    # Defaults to 0 when the top side is off.
    def border_top_size : Int32
      return 0 unless border_top? || implicit_borders?
      border_style.top_size
    end

    # Cell-width of the right border edge.
    # Defaults to 0 when the right side is off.
    def border_right_size : Int32
      return 0 unless border_right? || implicit_borders?
      border_style.right_size
    end

    # Cell-width of the bottom border edge.
    # Defaults to 0 when the bottom side is off.
    def border_bottom_size : Int32
      return 0 unless border_bottom? || implicit_borders?
      border_style.bottom_size
    end

    # Cell-width of the left border edge.
    # Defaults to 0 when the left side is off.
    def border_left_size : Int32
      return 0 unless border_left? || implicit_borders?
      border_style.left_size
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

    # Total horizontal border width, left + right.
    def horizontal_border_size : Int32
      border_left_size + border_right_size
    end

    # Total vertical border width, top + bottom.
    def vertical_border_size : Int32
      border_top_size + border_bottom_size
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

    # Expands CSS shorthand *sides* toggles to `{top, right, bottom, left}`.
    # No *sides* value provided means implicit "show them all".
    # 1-4 *sides* provided follows the same shorthand as `#padding`.
    # Raises when *sides*.size values provided is more than 4.
    private def which_sides_bool(sides : Array(Bool)) : {Bool, Bool, Bool, Bool}
      case sides.size
      when 0 then {true, true, true, true}
      when 1 then {sides[0], sides[0], sides[0], sides[0]}
      when 2 then {sides[0], sides[1], sides[0], sides[1]}
      when 3 then {sides[0], sides[1], sides[2], sides[1]}
      when 4 then {sides[0], sides[1], sides[2], sides[3]}
      else        raise ArgumentError.new("border accepts 0-4 side values, got #{sides.size}")
      end
    end

    # Expands CSS-shorthand *values* to `{top, right, bottom, left}`.
    #
    # Raises when *values*.size count is outside 1-4.
    private def expand_sides(values : Array(T)) : {T, T, T, T} forall T
      case values.size
      when 1 then {values[0], values[0], values[0], values[0]}
      when 2 then {values[0], values[1], values[0], values[1]}
      when 3 then {values[0], values[1], values[2], values[1]}
      when 4 then {values[0], values[1], values[2], values[3]}
      else        raise ArgumentError.new("CSS shorthand accepts 1-4 values, got #{values.size}")
      end
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
