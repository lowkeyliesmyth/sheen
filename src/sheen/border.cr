# TLDR; What functionality is in here?
# Border vocabulary: immutable glyph sets for frames and table separators, with named presets for common visual styles.

require "../foundation"

module Sheen
  # The characters that compose a box border:
  # - four edges
  # - four corners
  # - interior cross pieces used by tables
  #
  # A Border whose pieces are all empty is a "none" Border.
  #
  # Meta: Reopened so these methods live outside the `record` macro block but are still attached to the same struct.
  # Why do this? Because the `crystal docs` commands' `wants_doc` parser chokes on method docstring comments under the `record` macro.
  record Border,
    top : String = "",
    bottom : String = "",
    left : String = "",
    right : String = "",
    top_left : String = "",
    top_right : String = "",
    bottom_left : String = "",
    bottom_right : String = "",
    middle_left : String = "",
    middle_right : String = "",
    middle : String = "",
    middle_top : String = "",
    middle_bottom : String = ""

  struct Border
    # True when no border piece is set. You get a none Border.
    def none? : Bool
      self == Border.new
    end

    # Cell-width of the top corner edges.
    # 0 if absent.
    def top_size : Int32
      edge_width(top_left, top_right)
    end

    # Cell-width of the right edge.
    def right_size : Int32
      edge_width(top_right, right, bottom_right)
    end

    # Cell-width of the bottom edge.
    def bottom_size : Int32
      edge_width(bottom_left, bottom, bottom_right)
    end

    # Cell-width of the left edge.
    def left_size : Int32
      edge_width(top_left, left, bottom_left)
    end

    # Widest cell-width among *pieces*.
    # Returns 0 when all *pieces* are empty.
    private def edge_width(*pieces : String) : Int32
      pieces.max_of { |piece| Border.max_rune_width(piece) }
    end

    # Max cell-width of any single grapheme in *piece*.
    # Returns 0 when *piece* is empty.
    def self.max_rune_width(piece : String) : Int32
      width = 0
      piece.each_grapheme do |grapheme|
        w = Foundation.grapheme_width(grapheme.to_s)
        width = w if w > width
      end
      width
    end

    # A standard single-stroke border with square corners
    def self.normal : Border
      new(
        top: "─",
        bottom: "─",
        left: "│",
        right: "│",
        top_left: "┌",
        top_right: "┐",
        bottom_left: "└",
        bottom_right: "┘",
        middle_left: "├",
        middle_right: "┤",
        middle: "┼",
        middle_top: "┬",
        middle_bottom: "┴",
      )
    end

    # A single-stroke border with rounded corners.
    def self.rounded : Border
      new(
        top: "─",
        bottom: "─",
        left: "│",
        right: "│",
        top_left: "╭",
        top_right: "╮",
        bottom_left: "╰",
        bottom_right: "╯",
        middle_left: "├",
        middle_right: "┤",
        middle: "┼",
        middle_top: "┬",
        middle_bottom: "┴",
      )
    end

    # A heavier, single-stroke thick boi border.
    def self.thick : Border
      new(
        top: "━",
        bottom: "━",
        left: "┃",
        right: "┃",
        top_left: "┏",
        top_right: "┓",
        bottom_left: "┗",
        bottom_right: "┛",
        middle_left: "┣",
        middle_right: "┫",
        middle: "╋",
        middle_top: "┳",
        middle_bottom: "┻",
      )
    end

    # Double-vision. A double-stroke border.
    def self.double : Border
      new(
        top: "═",
        bottom: "═",
        left: "║",
        right: "║",
        top_left: "╔",
        top_right: "╗",
        bottom_left: "╚",
        bottom_right: "╝",
        middle_left: "╠",
        middle_right: "╣",
        middle: "╬",
        middle_top: "╦",
        middle_bottom: "╩",
      )
    end

    # A fat, solid block border
    def self.block : Border
      new(
        top: "█",
        bottom: "█",
        left: "█",
        right: "█",
        top_left: "█",
        top_right: "█",
        bottom_left: "█",
        bottom_right: "█",
        middle_left: "█",
        middle_right: "█",
        middle: "█",
        middle_top: "█",
        middle_bottom: "█",
      )
    end

    # A half-block border that sits outside the frame
    def self.outer_half_block : Border
      new(
        top: "▀",
        bottom: "▄",
        left: "▌",
        right: "▐",
        top_left: "▛",
        top_right: "▜",
        bottom_left: "▙",
        bottom_right: "▟",
      )
    end

    # A half-block border that sits inside the frame
    def self.inner_half_block : Border
      new(
        top: "▄",
        bottom: "▀",
        left: "▐",
        right: "▌",
        top_left: "▗",
        top_right: "▖",
        bottom_left: "▝",
        bottom_right: "▘",
      )
    end

    # A border of single-cell spaces, holding a frame layout without strokes.
    def self.hidden : Border
      new(
        top: " ",
        bottom: " ",
        left: " ",
        right: " ",
        top_left: " ",
        top_right: " ",
        bottom_left: " ",
        bottom_right: " ",
        middle_left: " ",
        middle_right: " ",
        middle: " ",
        middle_top: " ",
        middle_bottom: " ",
      )
    end

    # A Markdown-table style border. Disable `top` and `bottom` for an actual valid MD table
    def self.markdown : Border
      new(
        top: "-",
        bottom: "-",
        left: "|",
        right: "|",
        top_left: "|",
        top_right: "|",
        bottom_left: "|",
        bottom_right: "+|",
        middle_left: "|",
        middle_right: "|",
        middle: "|",
        middle_top: "|",
        middle_bottom: "|",
      )
    end

    # An ASCII-only border
    def self.ascii : Border
      new(
        top: "-",
        bottom: "-",
        left: "|",
        right: "|",
        top_left: "+",
        top_right: "+",
        bottom_left: "+",
        bottom_right: "+",
        middle_left: "+",
        middle_right: "+",
        middle: "+",
        middle_top: "+",
        middle_bottom: "+",
      )
    end
  end
end
