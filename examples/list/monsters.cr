require "../examples"

module Examples::List::Monsters
  # A checklist of pokemon to catch, those already in the collection are checked off.
  ACQUIRED = %w[Caterpie Rattata Charmander Zapdos Nidoking Tyranitar]

  DIM       = Sheen::Style.new.foreground(Sheen.color("240")).margin_right(1)
  HIGHLIGHT = Sheen::Style.new.foreground(Sheen.color("#00d787")).margin_right(1)
  ITEM      = Sheen::Style.new.foreground(Sheen.color("255"))

  private def self.acquired?(node : Sheen::Tree::Node?) : Bool
    ACQUIRED.includes?(node.try(&.value))
  end

  def self.render : String
    Sheen::List.new(
      "Ho-Oh", "Pidgeot", "Beedril",
      "Caterpie", "Rattata", "Tyranitar",
      "Mewtwo", "Toedscool", "Charmander",
      "Zapdos", "Corviknight", "Espeon",
      "Nidoking",
    )
      .enumerator { |children, i| acquired?(children.at(i)) ? "✓" : "•" }
      .enumerator_style { |children, i| acquired?(children.at(i)) ? HIGHLIGHT : DIM }
      .item_style { |children, i| acquired?(children.at(i)) ? ITEM.strikethrough : ITEM }
      .render
  end
end

Examples.register("list/monsters") { Examples::List::Monsters.render }
