require "../examples"

module Examples::List::Simple
  def self.render : String
    Sheen::List.new(
      "Quartz",
      "Feldspar",
      "Mica",
      Sheen::List.new("Muscovite", "Biotite", "Lepidolite")
        .enumerator(:roman),
      "Olivine"
    ).render
  end
end

Examples.register("list/simple") { Examples::List::Simple.render }
