# TLDR; What functionality is in here?
# The Table data layer.

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

    # A `Data` backed by a mutable matrix of strings
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
  end
end
