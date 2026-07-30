require "../examples"

module Examples::Tree::Styles
  # A styled, nested tree with a mix of subtree style overrides applied.
  def self.render : String
    purple = Sheen::Style.new.foreground(Sheen.color("99")).margin_right(1)
    pink = Sheen::Style.new.foreground(Sheen.color("212")).margin_right(1)
    blue = Sheen::Style.new.foreground(Sheen.color("81")).margin_right(1)

    Sheen::Tree::Branch.new.root("Shiny").root_style(blue.underline.bold)
      .child(
        "Amethyst",
        "Topaz",
        Sheen::Tree::Branch.root("Beryl")
          .child("Emerald", "Aquamarine")
          .enumerator_style(pink)
          .item_style(purple.italic)
          .enumerator(:rounded),
        "Garnet",
        "Peridot",
      )
      .enumerator_style(purple).item_style(pink)
      .render
  end
end

Examples.register("tree/mix") { Examples::Tree::Styles.render }
