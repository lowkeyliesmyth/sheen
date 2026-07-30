require "../examples"

module Examples::Tree::Toggle
  # A specimen collection type file browser.

  BASE       = Sheen::Style.new.background(Sheen.color("57")).foreground(Sheen.color("225"))
  BLOCK      = BASE.padding(1, 3).margin(1, 3).width(40)
  ENUMERATOR = BASE.foreground(Sheen.color("212")).padding_right(1)
  DIR        = BASE.inline(true)
  TOGGLE     = BASE.foreground(Sheen.color("207")).padding_right(1)

  struct DirNode
    def initialize(@name : String, @open : Bool)
    end

    def to_s(io : IO) : Nil
      io << TOGGLE.render(@open ? "▼" : "▶") << DIR.render(@name)
    end
  end

  struct FileNode
    def initialize(@name : String)
    end

    def to_s(io : IO) : Nil
      io << BASE.render(@name)
    end
  end

  def self.render : String
    tree = Sheen::Tree::Branch.root(DirNode.new("~/collection", true))
      .enumerator(:rounded)
      .enumerator_style(ENUMERATOR)
      .child(
        DirNode.new("agates", false),
        Sheen::Tree::Branch.root(DirNode.new("quartz", true)).child(
          Sheen::Tree::Branch.root(DirNode.new("amethyst", true)).child(
            FileNode.new("geode.png"),
            FileNode.new("cluster.png"),
          ),
        ),
        Sheen::Tree::Branch.root(DirNode.new("beryl", true)).child(
          Sheen::Tree::Branch.root(DirNode.new("emerald", true)).child(
            FileNode.new("raw.png"),
            FileNode.new("faceted.png"),
          ),
        ),
        DirNode.new("feldspar", false),
      )
    BLOCK.render(tree.render)
  end
end

Examples.register("tree/toggle") { Examples::Tree::Toggle.render }
