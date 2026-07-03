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
        border_top_foreground: top, border_right_foreground: right,
        border_bottom_foreground: bottom, border_left_foreground: left,
      )
    end

    # Sets all four border background colors via CSS 1-4 shorthand values.
    # Raises on a value count outside 1-4.
    def border_background(*colors : TerminalColor | String | Int) : Style
      top, right, bottom, left = expand_sides(colors.to_a.map { |clr| Sheen.color(clr) })
      copy_with(
        border_top_background: top, border_right_background: right,
        border_bottom_background: bottom, border_left_background: left,
      )
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

    # Shared render path that joins bound content *strings*, normalizes, styles, and applies width/height limits to them.
    private def render_parts(strings : Array(String)) : String
      parts = strings.dup
      parts.unshift(@value) unless @value.empty?
      content = parts.join(' ')

      # pre-styling normalization order: tabs -> CRLF -> inline -> wrap
      content = expand_tabs(content)
      content = content.gsub("\r\n", "\n")
      content = content.delete('\n') if inline?
      # Why are we reading the raw @width here rather than the `width` getter?
      # Reason: Wrapping has to treat "no explicit width set" and "width set to 0" with the same "don't wrap me bro" behavior. Using @width here gives `Foundation.wrap` a confirmed non-nil arg.
      # Basically the equivalent of `width_set? && width > 0`
      if !inline? && (w = @width) && w > 0
        content = Foundation.wrap(content, w - horizontal_padding, "")
      end

      content = apply_sequence(sgr_sequence, content)

      # post-styling block shaping order: padding -> height -> align -> border -> margins
      content = apply_padding(content) unless inline?
      content = align_vertical_block(content) if height > 0
      content = align_horizontal_block(content) if content.includes?('\n') || width > 0
      content = apply_border(content) unless inline?
      content = apply_margins(content) unless inline?

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

    # Applies an already-resolved SGR *color* to *builder* as fg or bg.
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

    # Adds left/right then top/bottom padding around already-styled *content*.
    #
    # L-R spaces carry the whitespace styler.
    # T-B blank lines are filled later by horizontal alignment.
    private def apply_padding(content : String) : String
      seq = whitespace_sequence
      content = pad_lines(content, -padding_left, seq) if padding_left > 0
      content = pad_lines(content, padding_right, seq) if padding_right > 0
      content = ("\n" * padding_top) + content if padding_top > 0
      content = content + ("\n" * padding_bottom) if padding_bottom > 0
      content
    end

    # Pads each line by *n* cells: negative on the left, positive on the right.
    # The space run is wrapped with *seq* styling.
    private def pad_lines(content : String, n : Int32, seq : String) : String
      spaces = style_run(seq, " " * n.abs)
      content.split('\n').map do |line|
        n > 0 ? line + spaces : spaces + line
      end.join('\n')
    end

    # Adds L/R then T/B margins around the shaped block containing *content*. Margin space is filled to the block width and carries only the margin background.
    private def apply_margins(content : String) : String
      seq = margin_sequence
      content = pad_lines(content, -margin_left, seq) if margin_left > 0
      content = pad_lines(content, margin_right, seq) if margin_right > 0

      if margin_top > 0 || margin_bottom > 0
        spaces = " " * content.split('\n').max_of { |line| Foundation.string_width(line) }
        content = style_run(seq, (spaces + "\n") * margin_top) + content if margin_top > 0
        content = content + style_run(seq, ("\n" + spaces) * margin_bottom) if margin_bottom > 0
      end
      content
    end

    # Draws the border around already-shaped *content*. Uses explicit side flags or implicit all-sides when only a style is set
    #
    # Corners are dropped when the adjacent side is hidden. Each edge and corner carries its own color.
    private def apply_border(content : String) : String
      has_top, has_right, has_bottom, has_left = border_sides

      border = border_style

      return content if border.none?
      return content unless has_top || has_right || has_bottom || has_left

      lines = content.split('\n')
      width = lines.max_of { |line| Foundation.string_width(line) }
      edges = resolve_border_edges(border, width, has_top, has_right, has_bottom, has_left)

      String.build do |io|
        io << render_top_edge(edges) << '\n' if has_top
        io << render_border_body(lines, edges, has_left, has_right)
        io << '\n' << render_bottom_edge(edges) if has_bottom
      end
    end

    # Resolves which border sides are visible, defaulting to true for all four visible when borders are implicit.
    private def border_sides : {Bool, Bool, Bool, Bool}
      implicit_borders? ? {true, true, true, true} : {border_top?, border_right?, border_bottom?, border_left?}
    end

    # Normalized border geometry for the visible *has_* sides:
    # - empty shown edges become spaces
    # - *width* is widened for the left edge
    # - each corner is dropped/filled/trimmed
    private def resolve_border_edges(border : Border, width : Int32, has_top : Bool, has_right : Bool, has_bottom : Bool, has_left : Bool) : BorderEdges
      left = border.left
      right = border.right
      left = " " if has_left && left.empty?
      right = " " if has_right && right.empty?

      BorderEdges.new(
        top: border.top,
        bottom: border.bottom,
        left: left,
        right: right,
        tl: resolve_corner(border.top_left, has_top, has_left),
        tr: resolve_corner(border.top_right, has_top, has_right),
        bl: resolve_corner(border.bottom_left, has_bottom, has_left),
        br: resolve_corner(border.bottom_right, has_bottom, has_right),
        width: has_left ? width + Border.max_rune_width(left) : width,
      )
    end

    # Resolves a single *corner* rune:
    # - "" when either *side* is hidden
    # - " " when both *sides* show but the *corner* char is empty
    # - otherwise the corner's first rune
    private def resolve_corner(corner : String, side_a : Bool, side_b : Bool) : String
      return "" unless side_a && side_b
      first_rune(corner.empty? ? " " : corner)
    end

    # Renders the top *edges* (corners + fill) in its border colors.
    private def render_top_edge(edges : BorderEdges) : String
      style_border(
        render_horizontal_edge(edges.tl, edges.top, edges.tr, edges.width), border_top_foreground, border_top_background,
      )
    end

    # Renders the bottom *edges* (corners + fill)  in its border colors.
    private def render_bottom_edge(edges : BorderEdges) : String
      style_border(
        render_horizontal_edge(edges.bl, edges.bottom, edges.br, edges.width),
        border_bottom_foreground, border_bottom_background,
      )
    end

    # Renders content *lines* with the left+right *edge* runes interleaved per side
    private def render_border_body(lines : Array(String), edges : BorderEdges, has_left : Bool, has_right : Bool) : String
      left_runes = edges.left.chars
      right_runes = edges.right.chars
      left_index = 0
      right_index = 0

      String.build do |io|
        lines.each_with_index do |line, i|
          io << '\n' if i > 0
          if has_left
            io << style_border(left_runes[left_index].to_s, border_left_foreground, border_left_background)
            left_index = (left_index + 1) % left_runes.size
          end
          io << line
          if has_right
            io << style_border(right_runes[right_index].to_s, border_right_foreground, border_right_background)
            right_index = (right_index + 1) % right_runes.size
          end
        end
      end
    end

    private record BorderEdges,
      top : String,
      bottom : String,
      left : String,
      right : String,
      tl : String,
      tr : String,
      bl : String,
      br : String,
      width : Int32

    # Builds one horizontal edge. Starts with the *left* corner, then *middle* repeated to fill *width*, then *right* corner in an "advance then measure" type loop.
    private def render_horizontal_edge(left : String, middle : String, right : String, width : Int32) : String
      middle = " " if middle.empty?
      left_width = Foundation.string_width(left)
      right_width = Foundation.string_width(right)
      runes = middle.chars
      j = 0

      String.build do |io|
        io << left
        i = left_width + right_width
        while i < width + right_width
          rune = runes[j]
          io << rune
          i += Foundation.string_width(rune.to_s)
          j = (j + 1) % runes.size
        end
        io << right
      end
    end

    # Wraps a rendered border *piece* (a corner or edge string, already built from border characters) in its *foreground* and *background* colors.
    #
    # Returns it unchanged if neither resolves under the active profile.
    private def style_border(piece : String, fg : TerminalColor, bg : TerminalColor) : String
      fg_color = fg.resolve(@renderer)
      bg_color = bg.resolve(@renderer)
      return piece if fg_color.nil? && bg_color.nil?

      builder = Foundation::Style.new
      apply_color(builder, fg_color, foreground: true) if fg_color
      apply_color(builder, bg_color, foreground: false) if bg_color
      style_run(builder.to_s, piece)
    end

    # The first rune of *str* as a string. Or "" when empty.
    private def first_rune(str : String) : String
      str.empty? ? str : str[0].to_s
    end

    # SGR sequence for styling margin whitespace. A separate sequence styler than `whitespace_sequence`.
    private def margin_sequence : String
      builder = Foundation::Style.new
      if bg = @margin_background.try &.resolve(@renderer)
        apply_color(builder, bg, foreground: false)
      end
      builder.to_s
    end

    # Wraps *text* in *seq* and a reset.
    # Otherwise returns *text* unchanged when *seq* is empty.
    private def style_run(seq : String, text : String) : String
      seq.empty? ? text : "#{seq}#{text}#{Foundation::RESET_STYLE}"
    end

    # SGR sequence used to style inserted whitespace (padding / alignment fill). Only targets attributes that affect blank cells: `reverse` and `background`.
    private def whitespace_sequence : String
      builder = Foundation::Style.new
      builder.reverse if reverse?
      if bg = @background.try &.resolve(@renderer)
        apply_color(builder, bg, foreground: false)
      end
      builder.to_s
    end

    # Pads *content* with blank lines to reach `height`, positioned per `align_vertical`.
    # A non-named position adds no block fill.
    private def align_vertical_block(content : String) : String
      str_height = content.count('\n') + 1
      gap = height - str_height
      return content if gap <= 0

      case align_vertical
      when Position::CENTER then ("\n" * (gap // 2)) + content + ("\n" * (gap - gap // 2))
      when Position::BOTTOM then ("\n" * gap) + content
      when Position::TOP    then content + ("\n" * gap)
      else                       content
      end
    end

    # Pads every line of *content* with spaces to the block width, positioned per `align_horizontal`.
    # Block width is defined by the widest line, or `width` if larger. Fill carries whitespace styling.
    private def align_horizontal_block(content : String) : String
      seq = whitespace_sequence
      lines = content.split('\n')
      block_width = {lines.max_of { |line| Foundation.string_width(line) }, width}.max

      lines.map do |line|
        gap = block_width - Foundation.string_width(line)
        next line if gap <= 0

        case align_horizontal
        when Position::RIGHT
          style_run(seq, " " * gap) + line
        when Position::CENTER
          style_run(seq, " " * (gap // 2)) + line + style_run(seq, " "*(gap - gap // 2))
        else
          line + style_run(seq, " " * gap)
        end
      end.join('\n')
    end

    # Truncates each line of *content* to `max_width` visible cells. Returns content unchanged when `max_width` is unset.
    private def limit_width(content : String) : String
      width = @max_width
      return content unless width && width > 0
      content.split('\n').map do |line|
        Foundation.truncate(line, width)
      end.join('\n')
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
