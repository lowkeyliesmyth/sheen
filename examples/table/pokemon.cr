require "../examples"

module Examples::Table::Pokemon
  TYPE_COLORS = {
    "Bug"      => "#D7FF87",
    "Electric" => "#FDFF90",
    "Fire"     => "#FF7698",
    "Flying"   => "#FF87D7",
    "Grass"    => "#75FBAB",
    "Ground"   => "#FF875F",
    "Normal"   => "#929292",
    "Poison"   => "#7D5AFC",
    "Water"    => "#00E2C7",
  }

  DIM_TYPE_COLORS = {
    "Bug"      => "#97AD64",
    "Electric" => "#FCFF5F",
    "Fire"     => "#BA5F75",
    "Flying"   => "#C97AB2",
    "Grass"    => "#59B980",
    "Ground"   => "#C77252",
    "Normal"   => "#727272",
    "Poison"   => "#634BD0",
    "Water"    => "#439F8E",
  }

  # A subset of the original Kanto pokemon with their primary and secondary types listed. Rows are alternating dim-highlight.
  def self.render : String
    base_style = Sheen::Style.new.padding(0, 1)
    header_style = base_style.foreground(Sheen.color("#d0d0d0")).bold
    selected_style = base_style.foreground(Sheen.color("#01BE85")).background(Sheen.color("#00432F"))

    headers = ["#", "Name", "Primary", "Secondary", "Japanese"]
    data = [
      ["1", "Bulbasaur", "Grass", "Poison", "フシギダネ"],
      ["2", "Ivysaur", "Grass", "Poison", "フシギソウ"],
      ["3", "Venusaur", "Grass", "Poison", "フシギバナ"],
      ["4", "Charmander", "Fire", "", "ヒトカゲ"],
      ["5", "Charmeleon", "Fire", "", "リザード"],
      ["6", "Charizard", "Fire", "Flying", "リザードン"],
      ["7", "Squirtle", "Water", "", "ゼニガメ"],
      ["8", "Wartortle", "Water", "", "カメール"],
      ["9", "Blastoise", "Water", "", "カメックス"],
    ]

    Sheen::Table.new
      .border(Sheen::Border.normal)
      .border_style(Sheen::Style.new.foreground(Sheen.color("#444444")))
      .headers(headers.map(&.upcase))
      .rows(data)
      .style do |row, col|
        next header_style if row == Sheen::Table::HEADER_ROW
        next selected_style if data[row][1] == "Charizard"

        even = row.even?
        if {2, 3}.includes?(col) # Primary + Secondary Types

          palette = even ? DIM_TYPE_COLORS : TYPE_COLORS
          # Handle empty pokemon type fields by resolving them to to an empty string, otherwise resolve to the constant color hashes.
          base_style.foreground(Sheen.color(palette.fetch(data[row][col], "")))
        else
          base_style.foreground(Sheen.color(even ? "#8a8a8a" : "#d0d0d0"))
        end
      end
      .render
  end
end

Examples.register("table/pokemon") { Examples::Table::Pokemon.render }
