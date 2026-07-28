require "../examples"

module Examples::Table::Ansi
  # A tiny table whose second column holds prestyled ANSI text.
  def self.render : String
    faded = Sheen::Style.new.foreground(Sheen.color("#626262"))
    shiny = Sheen::Style.new.foreground(Sheen.color("#ff5fff"))

    Sheen::Table.new
      .row("Mercury", faded.render("Shiny"))
      .row("Glass", faded.render("Also shiny"))
      .row("Diamonds", shiny.render("The shiniest"))
      .render
  end
end

Examples.register("table/ansi") { Examples::Table::Ansi.render }
