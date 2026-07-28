require "../examples"

module Examples::Table::Chess
  # An 8x8 chess table.
  def self.render : String
    label_style = Sheen::Style.new.foreground(Sheen.color("241"))
    icon_style_top = Sheen::Style.new.foreground(Sheen.color("93"))
    icon_style_bottom = Sheen::Style.new.foreground(Sheen.color("79"))

    board = [
      ["♜", "♞", "♝", "♛", "♚", "♝", "♞", "♜"].map { |piece| icon_style_top.render(piece) },
      ["♟", "♟", "♟", "♟", "♟", "♟", "♟", "♟"].map { |piece| icon_style_top.render(piece) },
      [" ", " ", " ", " ", " ", " ", " ", " "].map { |piece| icon_style_top.render(piece) },
      [" ", " ", " ", " ", " ", " ", " ", " "].map { |piece| icon_style_top.render(piece) },
      [" ", " ", " ", " ", " ", " ", " ", " "].map { |piece| icon_style_bottom.render(piece) },
      [" ", " ", " ", " ", " ", " ", " ", " "].map { |piece| icon_style_bottom.render(piece) },
      ["♙", "♙", "♙", "♙", "♙", "♙", "♙", "♙"].map { |piece| icon_style_bottom.render(piece) },
      ["♖", "♘", "♗", "♕", "♔", "♗", "♘", "♖"].map { |piece| icon_style_bottom.render(piece) },
    ]

    table = Sheen::Table.new
      .border(Sheen::Border.normal)
      .border_row(true)
      .border_column(true)
      .rows(board)
      .style { |_row, _col| Sheen::Style.new.padding(0, 1) }

    ranks = label_style.render([" A", "B", "C", "D", "E", "F", "G", "H  "].join("   "))
    files = label_style.render([" 1", "2", "3", "4", "5", "6", "7", "8 "].join("\n\n "))

    Sheen.join_vertical(
      Sheen::Position::RIGHT,
      Sheen.join_horizontal(Sheen::Position::CENTER, files, table.render),
      ranks
    ) + "\n"
  end
end

Examples.register("table/chess") { Examples::Table::Chess.render }
