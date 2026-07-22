require "../examples"

module Examples::Tree::Simple
  # A nested tree drawn with the default enumerator.
  def self.render : String
    Sheen::Tree.root("Minerals")
      .child("Pyrite")
      .child(
        Sheen::Tree.new.root("Quartz")
          .child("Rose Quartz")
          .child("Smoky Quartz")
          .child("Milky Quartz")
          .child("Tiger's Eye"),
      )
      .child(
        Sheen::Tree.new.root("Mica")
          .child("Muscovite")
          .child("Biotite")
          .child("Lepidolite"),
      )
      .render
  end
end

Examples.register("tree/simple") { Examples::Tree::Simple.render }
