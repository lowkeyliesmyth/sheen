require "../examples"

module Examples::Tree::Gems
  def self.render : String
    enumerator_style = Sheen::Style.new.foreground(Sheen.color("63")).margin_right(1)
    root_style = Sheen::Style.new.foreground(Sheen.color("35"))
    item_style = Sheen::Style.new.foreground(Sheen.color("212"))

    Sheen::Tree.root("❖ Gemstones")
      .child(
        "Diamond",
        "Sapphire",
        Sheen::Tree.new.child(
          "Star Sapphire",
          "Padparadscha",
        ),
        "Emerald",
        "Opal",
        Sheen::Tree.new.child(
          "Fire Opal",
          "Black Opal",
          "Peruvian Opal"
        ),
        "Amethyst",
      )
      .enumerator(->Sheen::Tree.rounded_enumerator(Sheen::Children, Int32))
      .enumerator_style(enumerator_style)
      .root_style(root_style)
      .item_style(item_style)
      .render
  end
end

Examples.register("tree/gems") { Examples::Tree::Gems.render }
