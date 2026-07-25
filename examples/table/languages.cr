require "../examples"

module Examples::Table::Languages
  PURPLE     = "99"
  GRAY       = "245"
  LIGHT_GRAY = "241"

  def self.render : String
    header_style = Sheen::Style.new.foreground(Sheen.color(PURPLE)).bold.align(Sheen::Position::CENTER)
    cell_style = Sheen::Style.new.padding(0, 1).width(14)
    odd_row_style = cell_style.foreground(Sheen.color(GRAY))
    even_row_style = cell_style.foreground(Sheen.color(LIGHT_GRAY))
    border_style = Sheen::Style.new.foreground(Sheen.color(PURPLE))

    rows = [
      ["Crystal", "Compiled", "안녕하세요"],
      ["Ruby", "Dynamic", "こんにちは"],
      ["Golang", "Compiled", "你好"],
      ["Rust", "Compiled", "やあ"],
      ["Python", "Dynamic", "สวัสดี"],
    ]
    table = Sheen::Table.new
      .border(Sheen::Border.thick)
      .border_style(border_style)
      .style do |row, col|
        next header_style if row == Sheen::Table::HEADER_ROW

        style = row.even? ? even_row_style : odd_row_style
        # Make the second column a bit wider
        style = style.width(22).align(Sheen::Position::CENTER) if col == 1
        # Right-align every column but the label for funsies
        style = style.align(Sheen::Position::RIGHT) if !{0, 1}.includes?(col)

        style
      end
      .headers("LANGUAGE", "KIND", "GREETING?")
      .rows(rows)

    table.row("English", "Spoken", "Hello!")

    table.render
  end
end

Examples.register("table/languages") { Examples::Table::Languages.render }
