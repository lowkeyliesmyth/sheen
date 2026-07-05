require "../foundation"
require "./border"
require "./color"
require "./renderer"

module Sheen
  # Draws a `Style`'s border around already-shaped content. A short-lived collaborator is constructed per render.
  # Reads geometry and colors through the bound `Style`'s public getters.
  struct BorderPainter
    def initialize(@style : Style)
    end

    # Draws the border around already-shaped *content*. Uses explicit side flags or implicit all-sides when only a style is set.
    # Corners are dropped when the adjacent side is hiddern.
    # Each edge and corner carries its own color.
    def apply(content : String) : String
      has_top, has_right, has_bottom, has_left = border_sides

      border = @style.border_style

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
      if @style.implicit_borders?
        {true, true, true, true}
      else
        {@style.border_top?, @style.border_right?, @style.border_bottom?, @style.border_left?}
      end
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
        render_horizontal_edge(edges.tl, edges.top, edges.tr, edges.width), @style.border_top_foreground, @style.border_top_background,
      )
    end

    # Renders the bottom *edges* (corners + fill)  in its border colors.
    private def render_bottom_edge(edges : BorderEdges) : String
      style_border(
        render_horizontal_edge(edges.bl, edges.bottom, edges.br, edges.width),
        @style.border_bottom_foreground, @style.border_bottom_background,
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
            io << style_border(left_runes[left_index].to_s, @style.border_left_foreground, @style.border_left_background)
            left_index = (left_index + 1) % left_runes.size
          end
          io << line
          if has_right
            io << style_border(right_runes[right_index].to_s, @style.border_right_foreground, @style.border_right_background)
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
      fg_color = fg.resolve(renderer)
      bg_color = bg.resolve(renderer)
      return piece if fg_color.nil? && bg_color.nil?

      builder = Foundation::Style.new
      builder.foreground(fg_color) if fg_color
      builder.background(bg_color) if bg_color
      seq = builder.to_s
      seq.empty? ? piece : "#{seq}#{piece}#{Foundation::RESET_STYLE}"
    end

    # The first rune of *str* as a string. Or "" when empty.
    private def first_rune(str : String) : String
      str.empty? ? str : str[0].to_s
    end

    # The renderer bound to the style, for color resolution.
    private def renderer : Renderer
      @style.renderer
    end
  end
end
