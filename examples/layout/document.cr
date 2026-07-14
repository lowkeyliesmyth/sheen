require "../examples"

module Examples
  # The core functionality example consumer that exercises borders, joins, place, inheritance, and adaptive color together.
  module Layout
    WIDTH        = 96
    COLUMN_WIDTH = 30

    # Assembles the doc.
    def self.render : String
      String.build do |io|
        io << color_grid_selection
      end
    end

    # A 14x8 gradient swatch block. Each cell is two spaces of bg.
    private def self.color_grid_selection
      String.build do |io|
        color_grid(14, 8).each do |row|
          row.each { |hex| io << Sheen::Style.new.background(Sheen.color(hex)).render("  ") }
          io << '\n'
        end
      end
    end

    # Bilinear color blend across four corner hex colors.
    # Returns a *y_steps* x *x_steps* grid of hex strings, driven by `Foundation::RGB#blend`.
    def self.color_grid(x_steps : Int32, y_steps : Int32) : Array(Array(String))
      x0y0 = Foundation::RGB.parse("#F25D94")
      x1y0 = Foundation::RGB.parse("#EDFF82")
      x0y1 = Foundation::RGB.parse("#643AFF")
      x1y1 = Foundation::RGB.parse("#14F9D5")

      left = Array.new(y_steps) do |i|
        x0y0.blend(x0y1, i.to_f / y_steps)
      end
      right = Array.new(y_steps) do |i|
        x1y0.blend(x1y1, i.to_f / y_steps)
      end

      Array.new(y_steps) do |row|
        Array.new(x_steps) do |col|
          left[row].blend(right[row], col.to_f / x_steps).to_hex
        end
      end
    end
  end
end

Examples.register("layout") { Examples::Layout.render }
