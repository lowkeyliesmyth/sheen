require "../examples"

module Examples
  # The core functionality example consumer that exercises borders, joins, place, inheritance, and adaptive color together.
  module Layout
    WIDTH        = 96
    COLUMN_WIDTH = 30

    # Color Palette.
    NORMAL    = "#EEEEEE"
    SUBTLE    = Sheen::AdaptiveColor.new("#D9DDCF", "#383838")
    HIGHLIGHT = Sheen::AdaptiveColor.new("#874BFD", "#7D56F4")
    SPECIAL   = Sheen::AdaptiveColor.new("#43BF6D", "#73F59F")

    ACTIVE_TAB_BORDER = Sheen::Border.new(
      top: "─", bottom: " ", left: "│", right: "│",
      top_left: "╭", top_right: "╮", bottom_left: "┘", bottom_right: "└",
    )
    TAB_BORDER = Sheen::Border.new(
      top: "─", bottom: "─", left: "│", right: "│",
      top_left: "╭", top_right: "╮", bottom_left: "┴", bottom_right: "┴",
    )

    # Assembles the doc.
    def self.render : String
      String.build do |io|
        io << tabs_section << "\n\n"
        io << title_section << "\n\n"
        io << color_grid_section
      end
    end

    # The tab row. With one active tab and the remainder inactive, trailed by a bottom-border gap that carries the underline out to the doc width.
    private def self.tabs_section : String
      tab = Sheen::Style.new.border(TAB_BORDER).border_foreground(HIGHLIGHT).padding(0, 1)
      active_tab = tab.border(ACTIVE_TAB_BORDER)
      tab_gap = tab.border_top(false).border_left(false).border_right(false)

      row = Sheen.join_horizontal(
        Sheen::Position::TOP,
        active_tab.render("sheen"),
        tab.render("etch"),
        tab.render("icedtea"),
        tab.render("foundation"),
      )

      # -2 is here to account for `tab_gap`'s horizontal padding (1 + 1)
      gap = tab_gap.render(" " * {0, WIDTH - Sheen.width(row) - 2}.max)
      Sheen.join_horizontal(Sheen::Position::BOTTOM, row, gap)
    end

    # The title block: Stacked "sheen" cards, a description and info rule.
    private def self.title_section : String
      title_style = Sheen::Style.new
        .margin_left(1).margin_right(5).padding(0, 1)
        .italic.foreground("#FFF7DB").string("sheen")

      colors = color_grid(1, 5)
      title = String.build do |io|
        colors.each_with_index do |row, i|
          io << title_style.margin_left(i * 2).background(row[0]).to_s
          io << '\n' if i < colors.size - 1
        end
      end

      base = Sheen::Style.new.foreground(NORMAL)
      desc_style = base.margin_top(1)
      info_style = base.border_style(Sheen::Border.normal)
        .border_top(true).border_foreground(SUBTLE)

      desc = Sheen.join_vertical(
        Sheen::Position::LEFT,
        desc_style.render("Shiny. Crystal. Terminal. Styles."),
        info_style.render(divider + url("https://github.com/lowkeyliesmyth/sheen")),
      )

      Sheen.join_horizontal(Sheen::Position::TOP, title, desc)
    end

    # Separator character in the title info
    private def self.divider : String
      Sheen::Style.new.string("•").padding(0, 1).foreground(SUBTLE).to_s
    end

    # Fancy URL *text* rendering, not a real OSC8 hyperlink.
    private def self.url(text : String) : String
      Sheen::Style.new.foreground(SPECIAL).render(text)
    end

    # A 14x8 gradient swatch block. Each cell is two spaces of bg.
    private def self.color_grid_section : String
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
