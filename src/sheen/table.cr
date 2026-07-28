# TLDR; What functionality is in here?
# The Table structure data model.
require "./border"
require "./style"

module Sheen
  # A table renderer.
  class Table
    # A readonly source of table cells, addressed by (row, column).
    abstract class Data
      # The cell at (*row*, *cell*), or "" when out of range.
      abstract def at(row : Int32, cell : Int32) : String
      # The number of rows.
      abstract def rows : Int32
      # The number of columns.
      abstract def columns : Int32
    end

    # The header row sentinel passed to the `#style` block for header cells.
    HEADER_ROW = -1

    @style_picker : (Int32, Int32) -> Style
    getter border : Border
    getter? border_top : Bool
    getter? border_right : Bool
    getter? border_bottom : Bool
    getter? border_left : Bool
    getter? border_header : Bool
    getter? border_column : Bool
    getter? border_row : Bool
    getter border_style : Style
    getter headers : Array(String)
    getter data : Data
    getter width : Int32
    getter height : Int32
    getter offset : Int32
    getter? wrap : Bool
    getter? use_manual_height : Bool

    # Builds an empty table with defaults:
    # - rounded border
    # - every border except row separator on
    # - wrapping enabled
    def initialize
      @style_picker = ->Table.default_styles(Int32, Int32)
      @border = Border.rounded
      @border_top = true
      @border_right = true
      @border_bottom = true
      @border_left = true
      @border_header = true
      @border_column = true
      @border_row = false
      @border_style = Style.new
      @headers = [] of String
      @data = StringData.new
      @width = 0
      @height = 0
      @use_manual_height = false
      @offset = 0
      @wrap = true
    end

    # The default per-cell style. No attributes for any position.
    def self.default_styles(_row : Int32, _col : Int32) : Style
      Style.new
    end

    # Sets the per-cell style *block* invoked with (row, column). The header row is `HEADER_ROW`.
    #
    # Returns self.
    def style(&block : Int32, Int32 -> Style) : Table
      @style_picker = block
      self
    end

    # The style for the cell at (*row*, *col*). The header row is `HEADER_ROW`.
    def cell_style(row : Int32, col : Int32) : Style
      @style_picker.call(row, col)
    end

    # Sets the table data *source*.
    #
    # Returns self.
    def data(source : Data) : Table
      @data = source
      self
    end

    # Clears all the data rows.
    #
    # Returns self.
    def clear_rows! : Table
      @data = StringData.new
      self
    end

    # Appends a row build from *cells*, when the data source is a `StringData`
    #
    # Returns self.
    def row(*cells : String) : Table
      append_row(cells.to_a)
      self
    end

    # Appends multiple *rows*, when the data source is a `StringData`.
    #
    # Returns self.
    def rows(*rows : Array(String)) : Table
      rows.each { |row| append_row(row) }
      self
    end

    # :ditto:
    def rows(rows : Enumerable(Array(String))) : Table
      rows.each { |row| append_row(row) }
      self
    end

    # Sets the table headers from each one of *names*.
    #
    # Returns self.
    def headers(*names : String) : Table
      @headers = names.to_a
      self
    end

    # :ditto:
    def headers(names : Enumerable(String)) : Table
      @headers = names.to_a.dup
      self
    end

    # Sets the border glyph set.
    #
    # Returns self.
    def border(border : Border) : Table
      @border = border
      self
    end

    # Toggles the top border on or off.
    #
    # Returns self.
    def border_top(val : Bool) : Table
      @border_top = val
      self
    end

    # Toggles the right border on or off.
    #
    # Returns self.
    def border_right(val : Bool) : Table
      @border_right = val
      self
    end

    # Toggles the bottom border on or off.
    #
    # Returns self.
    def border_bottom(val : Bool) : Table
      @border_bottom = val
      self
    end

    # Toggles the left border on or off.
    #
    # Returns self.
    def border_left(val : Bool) : Table
      @border_left = val
      self
    end

    # Toggles the header separator border on or off.
    #
    # Returns self.
    def border_header(val : Bool) : Table
      @border_header = val
      self
    end

    # Toggles the column border separator on or off.
    #
    # Returns self.
    def border_column(val : Bool) : Table
      @border_column = val
      self
    end

    # Toggles the row border separator on or off.
    #
    # Returns self.
    def border_row(val : Bool) : Table
      @border_row = val
      self
    end

    # Sets the *style* applied to every border.
    #
    # Returns self.
    def border_style(style : Style) : Table
      @border_style = style
      self
    end

    # Sets the target table *w*idth in columns. The resizer expands or shrinks columns to fit.
    #
    # Returns self.
    def width(w : Int32) : Table
      @width = w
      self
    end

    # Sets a manual table *h*eight in rows. Clipped rows overflow to an ellipses.
    #
    # Returns self.
    def height(h : Int32) : Table
      @height = h
      @use_manual_height = true
      self
    end

    # Sets the starting row *o*ffset for rendering.
    #
    # Returns self.
    def offset(o : Int32) : Table
      @offset = o
      self
    end

    # Sets whether cell content wraps or not.
    #
    # Returns self.
    def wrap(w : Bool) : Table
      @wrap = w
      self
    end

    # Appends *row* only when the data source is a mutable `StringData`
    private def append_row(row : Array(String)) : Nil
      data = @data
      data.append(row) if data.is_a?(StringData)
    end

    # A `Data` backed by a mutable matrix of strings.
    class StringData < Data
      def initialize(@rows : Array(Array(String)) = [] of Array(String))
        @columns = 0
        @rows.each { |row| @columns = {@columns, row.size}.max }
      end

      # Appends *row*, widening the column count if needed.
      #
      # Returns self
      def append(row : Array(String)) : StringData
        @columns = {@columns, row.size}.max
        @rows << row
        self
      end

      # Appends a row built from *cells*.
      #
      # Returns self.
      def item(*cells : String) : StringData
        append(cells.to_a)
      end

      # The cell at (*row*, *cell*), or "" when out of range.
      def at(row : Int32, cell : Int32) : String
        return "" if row < 0 || row >= @rows.size
        line = @rows[row]
        return "" if cell < 0 || cell >= line.size
        line[cell]
      end

      # The number of rows
      def rows : Int32
        @rows.size
      end

      # The number of columns.
      def columns : Int32
        @columns
      end
    end

    # A `Data` presenting a predicate-filtered view of another `Data`'s rows. `columns` are never touched.
    # Filtered out rows are skipped and reindexing is applied over survivors.
    class Filter < Data
      @predicate : Int32 -> Bool

      # Wraps *data*. Every row passes until `#filter` is set.
      def initialize(@data : Data)
        @predicate = ->(_row : Int32) { true }
      end

      # Sets the predicate *block* deciding whether the row at each index is kept.
      #
      # Returns self.
      def filter(&block : Int32 -> Bool) : Filter
        @predicate = block
        self
      end

      # The cell at the *row*-th passing row and *cell* column, or "" when out of range
      def at(row : Int32, cell : Int32) : String
        j = 0
        @data.rows.times do |i|
          next unless @predicate.call(i)
          return @data.at(i, cell) if j == row
          j += 1
        end
        ""
      end

      # The wrapped data's column count
      def columns : Int32
        @data.columns
      end

      # The number of passing rows.
      def rows : Int32
        count = 0
        @data.rows.times { |i| count += 1 if @predicate.call(i) }
        count
      end
    end

    # Materializes *data* into a dense row-based matrix, normalizing row padding to the max column size.
    def self.data_to_matrix(data : Data) : Array(Array(String))
      Array(Array(String)).new(data.rows) do |i|
        Array(String).new(data.columns) { |j| data.at(i, j) }
      end
    end

    # Renders the table to a string. Pads headers out to the column count in place.
    def render : String
      has_headers = !@headers.empty?
      has_rows = @data.rows > 0
      return "" unless has_headers || has_rows

      # (@headers.size...@data.columns).each { @headers << "" } if has_headers
      (@headers.size...@data.columns).each do |_i|
        @headers << ""
      end if has_headers

      matrix = Table.data_to_matrix(@data)
      widths, heights = TableResizer.new(self, matrix).resize
      TablePainter.new(self, widths, heights).render
    end

    # Renders the table to *io*.
    def to_s(io : IO) : Nil
      io << render
    end
  end
end
