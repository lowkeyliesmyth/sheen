require "../examples"

module Examples
  # The core functionality example consumer that exercises borders, joins, place, inheritance, and adaptive color together.
  module Layout
    WIDTH        = 96
    COLUMN_WIDTH = 30

    # Color Palette.
    NORMAL    = Sheen::AdaptiveColor.new("#383838", "#EEEEEE")
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
        io << dialog_section << "\n\n"
        io << lists_section
        io << paragraph_section << "\n\n"
        io << status_bar_section
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

    # Per-char foreground sweep over *text*, cycling through *colors*.
    # *base* supplies the base styling.
    #
    # Returns a fully styled String.
    def self.rainbow(base : Sheen::Style, text : String, colors : Array(Foundation::RGB)) : String
      String.build do |io|
        text.each_char.with_index do |char, i|
          io << base.foreground(Sheen.color(colors[i % colors.size].to_hex)).render(char.to_s)
        end
      end
    end

    # The 50-stop pink to yellow gradient behind the dialog prompt text.
    private def self.blends : Array(Foundation::RGB)
      from = Foundation::RGB.parse("#F25D94")
      to = Foundation::RGB.parse("#EDFF82")
      Array.new(50) { |i| from.blend(to, i / 49.0) }
    end

    # A centered, rounded-border dialog in a 96x9 field. The background is a tiled repeating "猫咪".
    private def self.dialog_section : String
      dialog_box_style = Sheen::Style.new
        .border(Sheen::Border.rounded)
        .border_foreground("#874BFD")
        .padding(1, 0)

      button_style = Sheen::Style.new
        .foreground("#FFF7DB").background("#888B7E").padding(0, 3).margin_top(1)
      active_button_style = button_style
        .background("#F25D94").margin_right(2).underline

      ok_button = active_button_style.render("Love 'em")
      cancel_button = button_style.render("Like 'em")

      question = Sheen::Style.new.width(50).align(Sheen::Position::CENTER)
        .render(rainbow(Sheen::Style.new, "Do you like shiny things?", blends))

      buttons = Sheen.join_horizontal(Sheen::Position::TOP, ok_button, cancel_button)
      ui = Sheen.join_vertical(Sheen::Position::CENTER, question, buttons)

      Sheen.place(
        WIDTH, 9,
        Sheen::Position::CENTER, Sheen::Position::CENTER,
        dialog_box_style.render(ui),
        ws_chars: "•☐", ws_foreground: SUBTLE,
      )
      # •☐
      # 猫咪
    end

    # Two bordered list columns, joined with the color-grid swatch block
    private def self.lists_section : String
      list_style = Sheen::Style.new
        .border(Sheen::Border.normal, false, true, false, false)
        .border_foreground(SUBTLE)
        .margin_right(2)
        .height(8)
        .width(COLUMN_WIDTH + 1)

      lists = Sheen.join_horizontal(
        Sheen::Position::TOP,
        list_style.render(
          Sheen.join_vertical(
            Sheen::Position::LEFT,
            list_header("Shiny Things to Get"),
            list_done("Diamonds"),
            list_done("Crystals"),
            list_done("Rubies"),
            list_done("Obsidian"),
            list_done("Coins"),
            list_item("Terminals"),
          ),
        ),
        list_style.width(COLUMN_WIDTH).render(
          Sheen.join_vertical(
            Sheen::Position::LEFT,
            list_header("Another List Bro"),
            list_item("First"),
            list_done("Second"),
            list_item("Third"),
          ),
        ),
      )

      Sheen.join_horizontal(Sheen::Position::TOP, lists, color_grid_section)
    end

    # A list column header, *text* with a bottom separator.
    private def self.list_header(text : String) : String
      Sheen::Style.new.foreground(NORMAL)
        .border_style(Sheen::Border.normal).border_bottom(true)
        .border_foreground(SUBTLE).margin_right(2).render(text)
    end

    # A plain, indented list item containing *text*.
    private def self.list_item(text : String) : String
      box = Sheen::Style.new.string("☐").foreground(SPECIAL).padding_right(1).to_s
      box + Sheen::Style.new.foreground(NORMAL).render(text)
    end

    # A completed list item with struck through *text*.
    private def self.list_done(text : String) : String
      done = Sheen::Style.new.string("☑").foreground(SPECIAL).padding_right(1).to_s
      done + Sheen::Style.new.strikethrough
        .foreground(Sheen::AdaptiveColor.new("#969B86", "#696969")).render(text)
    end

    # Three paragraphs, right- center- left- aligned respectively, with a highlighted background.
    private def self.paragraph_section : String
      par_a = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla imperdiet, ex quis pulvinar pulvinar, eros nisl feugiat neque, at luctus metus metus at libero. Phasellus tincidunt lacinia mi nec efficitur. Aliquam finibus imperdiet sodales. Interdum et malesuada fames ac ante ipsum primis in faucibus."
      par_b = "Maecenas fringilla porttitor felis eget auctor. Etiam semper neque congue, luctus nibh vitae, eleifend libero. Duis volutpat urna sit amet faucibus ultrices. Maecenas at pulvinar nibh. Sed tincidunt at nisi vel lobortis. Integer luctus turpis quis aliquet consequat. Donec faucibus neque nec varius posuere." # ameba:disable Lint/Typos
      par_c = "Ut ut auctor magna, in commodo lorem. Nunc vitae lacus molestie, molestie mauris et, dapibus tellus. Integer consectetur dui vitae lacus malesuada, quis accumsan purus mollis. Pellentesque iaculis ligula nec tempus maximus. Proin lacinia, quam eget posuere finibus, neque sem tempor urna, vestibulum elementum massa dolor sit amet dolor."

      paragraph_style = Sheen::Style.new
        .align(Sheen::Position::LEFT)
        .foreground("#FAFAFA")
        .background(HIGHLIGHT)
        .margin(1, 3, 0, 0)
        .padding(1, 2)
        .height(19)
        .width(COLUMN_WIDTH)

      Sheen.join_horizontal(
        Sheen::Position::TOP,
        paragraph_style.align(Sheen::Position::RIGHT).render(par_a),
        paragraph_style.align(Sheen::Position::CENTER).render(par_b),
        paragraph_style.margin_right(0).render(par_c),
      )
    end

    # The bottom status bar: a colored key, a filler bar, and two right-side nugget sections.
    private def self.status_bar_section : String
      status_nugget = Sheen::Style.new.foreground("#FFFDF5").padding(0, 1)

      status_bar_style = Sheen::Style.new
        .foreground(Sheen::AdaptiveColor.new("#343433", "#C1C6B2"))
        .background(Sheen::AdaptiveColor.new("#D9DCCF", "#353533"))

      status_style = Sheen::Style.new
        .inherit(status_bar_style)
        .foreground("#FFFDF5").background("#FF5F87")
        .padding(0, 1).margin_right(1)

      encoding_style = status_nugget.background("#A550DF").align(Sheen::Position::RIGHT)
      gem_style = status_nugget.background("#6124DF")
      status_text = Sheen::Style.new.inherit(status_bar_style)

      status_key = status_style.render("STATUS")
      encoding = encoding_style.render("UTF-9000")
      gem = gem_style.render("💎 Gems")
      status_val = status_text
        .width(WIDTH - Sheen.width(status_key) - Sheen.width(encoding) - Sheen.width(gem))
        .render("Shimmering")

      bar = Sheen.join_horizontal(
        Sheen::Position::TOP,
        status_key, status_val, encoding, gem
      )

      status_bar_style.width(WIDTH).render(bar)
    end
  end
end

Examples.register("layout") { Examples::Layout.render }
