require "../foundation"
require "./position"

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
end
