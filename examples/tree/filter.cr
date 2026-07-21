require "../examples"

module Examples::Tree::Filter
  # Builds a tree from a flat datasource, hiding the speciments still waiting to be identified.
  def self.render : String
    specimens = Sheen.string_data(
      "Rose Quartz",
      "Unidentified",
      "Malachite",
      "Benitoite",
      "Unidentified",
      "Pyrite",
    )

    catalogued = Sheen::Filter.new(specimens).filter do |node, _index|
      node.value != "Unidentified"
    end

    Sheen::Tree.root("Display Case").child(catalogued).render
  end
end

Examples.register("tree/filter") { Examples::Tree::Filter.render }
