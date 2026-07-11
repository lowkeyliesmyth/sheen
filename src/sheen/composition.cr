# TLDR; What functionality is in here?
# Block layout engine: combines separate rendered blocks through horizontal/vertical joining and placement inside a sized box.

require "../foundation"
require "./color"
require "./position"
require "./renderer"

module Sheen
  # Visible cell width of the widest line in *string* (ANSI-aware, grapheme based).
  def self.width(string : String) : Int32
    string.split('\n').max_of { |line| Foundation.string_width(line) }
  end

  # Height of *string* in lines: one more than its newline count.
  def self.height(string : String) : Int32
    string.count('\n') + 1
  end

  # The `{width, height}` of *string* in cells
  def self.size(string : String) : {Int32, Int32}
    {width(string), height(string)}
  end

  # Joins *strings* left to right, aligning blocks of differing height along the vertical axis at *pos* (0.0=top, 0.5=center, 1.0=bottom, or any float in between).
  # Each block's lines are padded to its own widest line so columns stay aligned.
  def self.join_horizontal(pos : Position, *strings : String) : String
    list = strings.to_a
    return list.first if list.size == 1

    blocks = list.map(&.split('\n'))
    widths = list.map { |str| width(str) }
    max_height = blocks.max_of(&.size)

    # Pad each block vertically to the tallest, positioning content per pos.
    blocks = blocks.map do |block|
      gap = max_height - block.size
      next block if gap == 0
      # Round half away from zero. Gap and fraction are >= 0
      above = (gap * pos.fraction + 0.5).to_i
      below = gap - above
      Array.new(above, "") + block + Array.new(below, "")
    end

    String.build do |io|
      (0...max_height).each do |row|
        blocks.each_with_index do |block, j|
          line = block[row]
          io << line << " " * (widths[j] - Foundation.string_width(line))
        end
        io << '\n' if row < max_height - 1
      end
    end
  end

  # Joins *strings* top to bottom, aligning lines of differing width along the horizontal axis at *pos* (0.0=left, 0.5=center, 1.0=right, or any float in between).
  # All lines are padded to the widest line across every block
  def self.join_vertical(pos : Position, *strings : String) : String
    list = strings.to_a
    return list.first if list.size == 1

    blocks = list.map(&.split('\n'))
    max_width = list.max_of { |str| width(str) }

    String.build do |io|
      last_block = blocks.size - 1
      blocks.each_with_index do |block, i|
        last_line = block.size - 1
        block.each_with_index do |line, j|
          gap = max_width - Foundation.string_width(line)

          case pos
          when Position::LEFT
            io << line << " " * gap
          when Position::RIGHT
            io << " " * gap << line
          else
            if gap < 1
              io << line
            else
              # Round halfway from zero for non-negative inputs
              split = (gap * pos.fraction + 0.5).to_i
              right = gap - split
              # favor the left side on odd gaps
              left = gap - right
              io << " " * left << line << " " * right
            end
          end

          io << '\n' unless i == last_block && j == last_line
        end
      end
    end
  end

  # Places *string* inside a box of *width* x *height*, aligning it at *h_pos* horizontally and *v_pos* vertically.
  # Extra space is filled with whitespace which can be styled via the *ws_** keyword options.
  #
  # If *width* or *height* is not larger than *string*'s own width or height, that axis is left unchanged.
  def self.place(width : Int32, height : Int32, h_pos : Position, v_pos : Position, string : String, *, ws_chars : String = " ", ws_foreground : TerminalColor? = nil, ws_background : TerminalColor? = nil, renderer : Renderer = Sheen.renderer) : String
    placed = place_horizontal(
      width,
      h_pos,
      string,
      ws_chars: ws_chars,
      ws_foreground: ws_foreground,
      ws_background: ws_background,
      renderer: renderer
    )

    place_vertical(
      height,
      v_pos,
      placed,
      ws_chars: ws_chars,
      ws_foreground: ws_foreground,
      ws_background: ws_background,
      renderer: renderer
    )
  end

  # Places *string* horizontally in a box of *width* at *pos* (0.0=left ... 1.0=right).
  # Each line pads to fill up the full *width*, but if *width* <= the widest line then no change is applied.
  def self.place_horizontal(width : Int32, pos : Position, string : String, *, ws_chars : String = " ", ws_foreground : TerminalColor? = nil, ws_background : TerminalColor? = nil, renderer : Renderer = Sheen.renderer) : String
    lines = string.split('\n')
    content_width = lines.max_of { |line| Foundation.string_width(line) }
    gap = width - content_width
    return string if gap <= 0

    String.build do |io|
      lines.each_with_index do |line, i|
        short = content_width - Foundation.string_width(line)
        case pos
        when Position::LEFT
          io << line << render_whitespace(renderer, gap + short, ws_chars, ws_foreground, ws_background)
        when Position::RIGHT
          io << render_whitespace(renderer, gap + short, ws_chars, ws_foreground, ws_background) << line
        else
          total = gap + short
          split = (total * pos.fraction + 0.5).to_i
          left = total - split
          right = total - left
          io << render_whitespace(renderer, left, ws_chars, ws_foreground, ws_background)
          io << line
          io << render_whitespace(renderer, right, ws_chars, ws_foreground, ws_background)
        end
        io << '\n' if i < lines.size - 1
      end
    end
  end

  # Places *string* vertically in a box of *height* at *pos* (0.0=top ... 1.0=bottom). Blank lines fill up the the full block width.
  # If *height* <= the string's line count then no change is applied.
  def self.place_vertical(height : Int32, pos : Position, string : String, *, ws_chars : String = " ", ws_foreground : TerminalColor? = nil, ws_background : TerminalColor? = nil, renderer : Renderer = Sheen.renderer) : String
    gap = height - self.height(string)
    return string if gap <= 0

    empty = render_whitespace(renderer, width(string), ws_chars, ws_foreground, ws_background)

    String.build do |io|
      case pos
      when Position::TOP
        io << string
        gap.times { io << '\n' << empty }
      when Position::BOTTOM
        gap.times { io << empty << '\n' }
        io << string
      else
        split = (gap * pos.fraction + 0.5).to_i
        top = gap - split
        bottom = gap - top
        top.times { io << empty << '\n' }
        io << string
        bottom.times { io << '\n' << empty }
      end
    end
  end

  # Fills *width* cells by cycling *chars* (a space by default), padding any trailing gap that a wide rune leaves, then wrapping the run in the whitespace *foreground* + *background* styling.
  #
  # Empty when *width* <= 0.
  private def self.render_whitespace(renderer : Renderer, width : Int32, chars : String, foreground : TerminalColor?, background : TerminalColor?) : String
    return "" if width <= 0

    chars = " " if chars.empty?
    runes = chars.chars
    j = 0
    filled = String.build do |io|
      i = 0
      while i < width
        io << runes[j]
        j = (j + 1) % runes.size
        i += Foundation.string_width(runes[j].to_s)
      end
    end

    short = width - Foundation.string_width(filled)
    filled += " " * short if short > 0

    builder = Foundation::Style.new

    if fg_color = foreground
      if resolved = fg_color.resolve(renderer)
        builder.foreground(resolved)
      end
    end

    if bg_color = background
      if resolved = bg_color.resolve(renderer)
        builder.background(resolved)
      end
    end
    sequence = builder.to_s

    sequence.empty? ? filled : "#{sequence}#{filled}#{Foundation::RESET_STYLE}"
  end
end
