# TLDR; What functionality is in here?
# The table column-width/row-height normalizer. It resizes tables, making columns fit a target width and rows a target height.

require "./table"
require "./composition"

module Sheen
  # Internal column-width and row-height optimizer for `Table`.
  #
  # Mutates column and height state throughout the optimization.
  class TableResizer
    # A single column's measured area during resizing.
    class Column
      property index : Int32
      property min : Int32
      property max : Int32
      property median : Int32
      property rows : Array(Array(String))
      property x_padding : Int32
      property fixed_width : Int32

      # Creates a column area tracker with the given index and initial min/max/median widths.
      def initialize(@index, @min, @max, @median)
        @rows = [] of Array(String)
        @x_padding = 0
        @fixed_width = 0
      end
    end

    @columns : Array(Column)

    # Sets up the resizer for *table* using the already-rendered *rows*.
    def initialize(@table : Table, @rows : Array(Array(String)))
      @table_width = @table.width
      @headers = @table.headers
      @wrap = @table.wrap?
      @border_column = @table.border_column?
      @all_rows = @headers.empty? ? @rows : ([@headers] + @rows)
      @columns = build_columns
      @row_heights = [] of Int32
      @y_paddings = [] of Array(Int32)
    end

    # Returns the optimized column widths and row heights. Expand the columns evenly to fit the width, distributing the surplus to the shortest columns first.
    def resize : {Array(Int32), Array(Int32)}
      has_headers = !@headers.empty?
      @y_paddings = @all_rows.map { |row| Array(Int32).new(row.size, 0) }
      @row_heights = default_row_heights

      @all_rows.each_with_index do |row, i|
        row.each_index do |j|
          col = @columns[j]
          row_index = has_headers ? i - 1 : i
          style = @table.cell_style(row_index, j)

          h_padding = style.horizontal_margins + style.horizontal_padding
          col.x_padding = {col.x_padding, h_padding}.max
          col.fixed_width = {col.fixed_width, style.width}.max
          @row_heights[i] = {@row_heights[i], style.height}.max
          @y_paddings[i][j] = style.vertical_margins + style.vertical_padding
        end
      end

      @table_width = detect_table_width if @table_width <= 0
      optimized_widths
    end

    # Builds the per-column min-max-median areas from raw cell widths.
    private def build_columns : Array(Column)
      columns = [] of Column
      @all_rows.each do |row|
        row.each_with_index do |cell, i|
          cell_len = Sheen.width(cell)
          if columns.size <= i
            columns << Column.new(i, cell_len, cell_len, cell_len)
          else
            col = columns[i]
            col.rows << row
            col.min = {col.min, cell_len}.min
            col.max = {col.max, cell_len}.max
          end
        end
      end
      columns.each do |col|
        widths = col.rows.map { |row| Sheen.width(row[col.index]) }
        col.median = median(widths)
      end
      columns
    end

    # Dispatch method, routes to expand or shrink the table depending on if the natural column widths fit the table width.
    private def optimized_widths : {Array(Int32), Array(Int32)}
      max_total <= @table_width ? expand_table_width : shrink_table_width
    end

    # Grows columns one character at a time until the table fills the target width.
    # Skips fixed width columns.
    private def expand_table_width : {Array(Int32), Array(Int32)}
      col_widths = max_column_widths
      loop do
        break if col_widths.sum + total_horizontal_border >= @table_width
        shorter_index = 0
        shorter_width = Int32::MAX
        col_widths.each_with_index do |width, j|
          next if width == @columns[j].fixed_width
          if width < shorter_width
            shorter_width = width
            shorter_index = j
          end
        end
        col_widths[shorter_index] += 1
      end
      {col_widths, expand_row_heights(col_widths)}
    end

    # Shrinks columns in prioritized stages (big -> median -> any) until the table fits the target width.
    private def shrink_table_width : {Array(Int32), Array(Int32)}
      col_widths = max_column_widths
      shrink_biggest_columns(col_widths, true)
      shrink_to_median(col_widths)
      shrink_biggest_columns(col_widths, false)
      {col_widths, expand_row_heights(col_widths)}
    end

    # Shrinks widest columns to *col_widths* until the table fits.
    #
    # With *very_big_only* enabled, only columns at least half the table width are candidates.
    private def shrink_biggest_columns(col_widths : Array(Int32), very_big_only : Bool) : Nil
      loop do
        break if col_widths.sum + total_horizontal_border <= @table_width
        big_index = Int32::MIN
        big_width = Int32::MIN
        col_widths.each_with_index do |width, j|
          next if width == @columns[j].fixed_width
          if very_big_only
            if width >= @table_width // 2 && width > big_width
              big_width = width
              big_index = j
            end
          elsif width > big_width
            big_width = width
            big_index = j
          end
        end
        break if big_index < 0 || col_widths[big_index] == 0
        col_widths[big_index] -= 1
      end
    end

    # Shrinks the columns to median width that exceed that median the most. Column 0 is never shrunk.
    private def shrink_to_median(col_widths : Array(Int32)) : Nil
      loop do
        break if col_widths.sum + total_horizontal_border <= @table_width
        biggest_diff = Int32::MIN
        biggest_index = Int32::MIN
        col_widths.each_with_index do |width, j|
          next if width == @columns[j].fixed_width
          diff = width - @columns[j].median
          if diff > 0 && diff > biggest_diff
            biggest_diff = diff
            biggest_index = j
          end
        end
        break if biggest_index <= 0 || col_widths[biggest_index] == 0
        col_widths[biggest_index] -= 1
      end
    end

    # When wrapping is enabled, expands row heights needed to fit wrapped content given the constrained *col_widths*.
    private def expand_row_heights(col_widths : Array(Int32)) : Array(Int32)
      row_heights = default_row_heights
      return row_heights unless @wrap
      @all_rows.each_with_index do |row, i|
        row.each_with_index do |cell, j|
          height = detect_content_height(cell, col_widths[j] - x_padding_for_col(j)) + y_padding_for_cell(i, j)
          row_heights[i] = height if height > row_heights[i]
        end
      end
      row_heights
    end

    # Returns the current row heights with a lower bound of 1.
    private def default_row_heights : Array(Int32)
      Array(Int32).new(@all_rows.size) do |i|
        h = i < @row_heights.size ? @row_heights[i] : 0
        h < 1 ? 1 : h
      end
    end

    # Returns each column's maximum natural width including horizontal padding.
    # Bounded to fixed width if set.
    private def max_column_widths : Array(Int32)
      @columns.map do |col|
        col.fixed_width > 0 ? col.fixed_width : col.max + x_padding_for_col(col.index)
      end
    end

    # Sums up the max widths of all columns also including horizontal padding.
    # Bounded to summed fixed width if set.
    private def max_total : Int32
      total = 0
      @columns.each_with_index do |col, j|
        total += col.fixed_width > 0 ? col.fixed_width : col.max + x_padding_for_col(j)
      end
      total
    end

    # Autocomputes the table width from content size, padding, and borders if none are explicitly set.
    private def detect_table_width : Int32
      max_char_count + total_horizontal_padding + total_horizontal_border
    end

    # Sums each column's max content width. Excludes fixed-width column padding.
    private def max_char_count : Int32
      count = 0
      @columns.each do |col|
        count += col.fixed_width > 0 ? col.fixed_width - x_padding_for_col(col.index) : col.max
      end
      count
    end

    # Sums the horizontal padding across all columns.
    private def total_horizontal_padding : Int32
      @columns.sum(&.x_padding)
    end

    # Column-separator border chars. One per column plus either a trailing one or none depending on border_column setting.
    private def total_horizontal_border : Int32
      @border_column ? @columns.size + 1 : 0
    end

    # Returns the horizontal padding for column *j*, or 0 if out of range.
    private def x_padding_for_col(j : Int32) : Int32
      j >= @columns.size ? 0 : @columns[j].x_padding
    end

    # Returns the vertical padding for cell (*i*, *j*), or 0 if out of range.
    private def y_padding_for_cell(i : Int32, j : Int32) : Int32
      return 0 if i >= @y_paddings.size || j >= @y_paddings[i].size
      @y_paddings[i][j]
    end

    # Detects how many lines *content* occupies when wrapped to *width*.
    private def detect_content_height(content : String, width : Int32) : Int32
      return 1 if width == 0
      height = 0
      content.gsub("\r\n", "\n").split('\n').each do |line|
        wrapped = width < 0 ? line : Foundation.wrap(line, width, "")
        height += wrapped.count('\n') + 1
      end
      height
    end

    # Returns the median of *values*, or 0 if empty.
    private def median(values : Array(Int32)) : Int32
      return 0 if values.empty?
      sorted = values.sort
      n = sorted.size
      n.even? ? (sorted[n // 2 - 1] + sorted[n // 2]) // 2 : sorted[n // 2]
    end
  end
end
