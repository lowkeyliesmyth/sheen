require "../examples"

module Examples::List::Glow
  FAINT    = Sheen::Style.new.faint
  SELECTED = 1

  # A catalog entry. A specimen name over a faint modification time.
  struct Entry
    def initialize(@name : String, @logged : String)
    end

    def to_s(io : IO) : Nil
      io << @name << '\n' << FAINT.render(@logged)
    end
  end

  ENTRIES = [
    Entry.new("quartz.md", "2 minutes ago"),
    Entry.new("amethyst.md", "1 hour ago"),
    Entry.new("pyrite.md", "1 week ago"),
  ]

  # The selected entry is marked with a multiline colored enumerator, while unselected entries just indent with a space.
  def self.render : String
    base = Sheen::Style.new.margin_bottom(1).margin_left(1)
    dim = Sheen.color("250")
    highlight = Sheen.color("#EE6FF8")

    list = Sheen::List.new
      .enumerator { |_children, i| i == SELECTED ? "|\n|" : " " }
      .item_style { |_children, i| i == SELECTED ? base.foreground(highlight) : base.foreground(dim) }
      .enumerator_style { |_children, i| i == SELECTED ? Sheen::Style.new.foreground(highlight) : Sheen::Style.new.foreground(dim) }

    ENTRIES.each { |entry| list.item(entry) }
    list.render
  end
end

Examples.register("list/glow") { Examples::List::Glow.render }
