require "../examples"

module Examples::List::DuckDuckGoose
  ENUM = Sheen::Style.new.foreground(Sheen.color("#00d787"))
  ITEM = Sheen::Style.new.foreground(Sheen.color("255"))

  # THE GOOSE IS LOOSE!
  # Custom enumerator that only honks at the goose.
  def self.render : String
    Sheen::List.new("Duck", "Duck", "Duck", "Goose", "Duck")
      .item_style(ITEM)
      .enumerator_style(ENUM)
      .enumerator do |children, i|
        children.at(i).try(&.value) == "Goose" ? "Honk →" : " "
      end
      .render
  end
end

Examples.register("list/ddg") { Examples::List::DuckDuckGoose.render }
