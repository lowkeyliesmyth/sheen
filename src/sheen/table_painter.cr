# TLDR; What functionality is in here?
# The table render pipeline.

require "./table"
require "./composition"

module Sheen
  # Renders a `Table` given the resizer's column widths and row heights.
  #
  # This is a readonly collaborator like other Sheen *painters, reads the Table through its getters and the resizer's widths.
  struct TablePainter
    def initialize(@table : Table, @widths : Array(Int32), @heights : Array(Int32))
    end

    # Assembles the borders, header, body, and clamps the table size.
    def render : String
      has_headers = !@table.headers.empty?
      data = @table.data

      top = String.build do |io|
        io << construct_top_border << '\n' if @table.border_top?
        io << construct_headers << '\n' if has_headers
      end

      bottom = @table.border_bottom? ? construct_bottom_border : ""

      body = String.build do |io|
        if data.rows > 0
          if @table.use_manual_height?
            top_height = Sheen.height(top) - 1
            available = @table.height - (top_height + Sheen.height(bottom))
            available = data.rows if available > data.rows
            io << construct_rows(available)
          else
            (@table.offset...data.rows).each { |row| io << construct_row(row, false) }
          end
        end
      end

      content = top + body + bottom

      style = Style.new.max_height(compute_height)
      style = style.max_width(@table.width) if @table.width > 0
      style.render(content)
    end

    # Builds the top border row. Its corners, per-column runs, and column junctions.
    private def construct_top_border : String
      border = @table.border
      String.build do |io|
        io << border_render(border.top_left) if @table.border_left?
        @widths.each_with_index do |wdt, i|
          io << border_render(border.top * wdt)
          io << border_render(border.middle_top) if i < @widths.size - 1 && @table.border_column?
        end
        io << border_render(border.top_right) if @table.border_right?
      end
    end

    # Builds the bottom border row. Its corners, per-column runs, and column junctions.
    private def construct_bottom_border : String
      border = @table.border
      String.build do |io|
        io << border_render(border.bottom_left) if @table.border_left?
        @widths.each_with_index do |wdt, i|
          io << border_render(border.bottom * wdt)
          io << border_render(border.middle_bottom) if i < @widths.size - 1 && @table.border_column?
        end
        io << border_render(border.bottom_right) if @table.border_right?
      end
    end

    # Builds the truncated and styled header cells plus the header separator row.
    private def construct_headers : String # ameba:disable Metrics/CyclomaticComplexity
      border = @table.border
      headers = @table.headers
      String.build do |io|
        io << border_render(border.left) if @table.border_left?
        headers.each_with_index do |header, i|
          io << @table.cell_style(Table::HEADER_ROW, i)
            .max_height(1)
            .width(@widths[i])
            .max_width(@widths[i])
            .render(Foundation.truncate(header, @widths[i], "…"))
          io << border_render(border.left) if i < headers.size - 1 && @table.border_column?
        end
        if @table.border_header?
          io << border_render(border.right) if @table.border_right?
          io << '\n'
          io << border_render(border.middle_left) if @table.border_left?
          headers.each_index do |i|
            io << border_render(border.top * @widths[i])
            io << border_render(border.middle) if i < headers.size - 1 && @table.border_column?
          end
          io << border_render(border.middle_right) if @table.border_right?
        end
        if @table.border_right? && !@table.border_header?
          io << border_render(border.right)
        end
      end
    end

    # Renders the data rows to fit *available_lines*, truncating the last row with ellipses when they overflow.
    private def construct_rows(available_lines : Int32) : String
      data = @table.data
      offset_row_count = data.rows - @table.offset
      rows_to_render = {available_lines, 1}.max
      needs_overflow = rows_to_render < offset_row_count
      row_idx = needs_overflow ? @table.offset : data.rows - rows_to_render
      String.build do |io|
        while rows_to_render > 0 && row_idx < data.rows
          is_overflow = needs_overflow && rows_to_render == 1
          io << construct_row(row_idx, is_overflow)
          row_idx += 1
          rows_to_render -= 1
        end
      end
    end

    # Builds one data row at *index*, truncated if *is_overflow*. Styled cells are joined with border columns and optional row separator.
    private def construct_row(index : Int32, is_overflow : Bool) : String # ameba:disable Metrics/CyclomaticComplexity
      border = @table.border
      data = @table.data
      has_headers = !@table.headers.empty?
      height = is_overflow ? 1 : @heights[index + (has_headers ? 1 : 0)]

      # Build each cell and left borders for the row
      cells = [] of String
      left = (border_render(border.left) + "\n") * height
      cells << left if @table.border_left?

      data.columns.times do |col|
        # Truncate cell content when wrapping is disabled.
        cell = is_overflow ? "…" : data.at(index, col)
        cell_style = @table.cell_style(index, col)
        unless @table.wrap?
          length = @widths[col] * height - cell_style.horizontal_padding
          cell = Foundation.truncate(cell, length, "…")
        end
        # Render the styled cell sized to the column width/row height.
        cells << cell_style
          .height(height - cell_style.vertical_margins)
          .max_height(height)
          .width(@widths[col] - cell_style.horizontal_margins)
          .max_width(@widths[col])
          .render(cell)
        cells << left if col < data.columns - 1 && @table.border_column?
      end

      # Cap the row off with the right border
      cells << (border_render(border.right) + "\n") * height if @table.border_right?

      cells = cells.map(&.rstrip('\n'))

      # Join all cells horizontally then append a row separator if needed
      String.build do |io|
        io << Sheen.join_horizontal(Position::TOP, cells) << '\n'
        if @table.border_row? && index < data.rows - 1
          io << border_render(border.middle_left)
          @widths.each_with_index do |wdt, i|
            io << border_render(border.bottom * wdt)
            io << border_render(border.middle) if i < @widths.size - 1 && @table.border_column?
          end
          io << border_render(border.middle_right) << '\n'
        end
      end
    end

    # Sums row heights plus header+border line counts to give total rendered line count.
    private def compute_height : Int32
      has_headers = !@table.headers.empty?
      @heights.sum - 1 + b_to_i(has_headers) +
        b_to_i(@table.border_top?) + b_to_i(@table.border_bottom?) +
        b_to_i(@table.border_header?) + @table.data.rows * b_to_i(@table.border_row?)
    end

    # Styles a single border *glyph* through the table's border style.
    private def border_render(glyph : String) : String
      @table.border_style.render(glyph)
    end

    # Translates a Bool true (1) or false (0) for line-count arithmetic.
    private def b_to_i(value : Bool) : Int32
      value ? 1 : 0
    end
  end
end
