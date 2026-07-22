require "../spec_helper"

# Testing helper. Builds the canonical three item list under *enumr*
private def enumerated(enumr : Sheen::Enumerator) : String
  Sheen::List.new("Foo", "Bar", "Baz").enumerator(enumr).render
end

describe Sheen::List do
  it "renders a simple bullet list without a root" do
    list = Sheen::List.new.item("Foo").item("Bar").item("Baz")
    list.render.should eq(<<-LIST.rstrip)
      • Foo
      • Bar
      • Baz
      LIST
  end

  it "accepts items from an array" do
    Sheen::List.new.items(["Foo", "Bar", "Baz"]).render.should eq(<<-LIST.rstrip)
    • Foo
    • Bar
    • Baz
    LIST
  end

  it "renders variadic constructor items" do
    Sheen::List.new("1", "2", "3").render.should eq(<<-LIST.rstrip)
    • 1
    • 2
    • 3
    LIST
  end

  it "nests a sublist by autopromoting its previous sibling to its parent" do
    list = Sheen::List.new
      .item("Foo")
      .item("Bar")
      .item(Sheen::List.new("Hi", "Hallo", "Hola").enumerator(->Sheen::List.roman(Sheen::Children, Int32)))
      .item("Qux")
    list.render.should eq(<<-LIST.rstrip)
      • Foo
      • Bar
          I. Hi
         II. Hallo
        III. Hola
      • Qux
      LIST
  end

  it "nests sublists passed as constructor items" do
    list = Sheen::List.new(
      "SUP",
      Sheen::List.new("vim", "emacs"),
      "HI",
      Sheen::List.new(["vscode", "zed"]),
      "YO",
      Sheen::List.new.item("Ehrmagerd its JertBurns"),
    )
    list.render.should eq(<<-LIST.rstrip)
    • SUP
      • vim
      • emacs
    • HI
      • vscode
      • zed
    • YO
      • Ehrmagerd its JertBurns
    LIST
  end

  it "reconciles multiline item heights" do
    list = Sheen::List.new
      .item("item1\nline2\nline3")
      .item("item2\nline2\nline3")
      .item("3")
    list.render.should eq(<<-LIST.rstrip)
    • item1
      line2
      line3
    • item2
      line2
      line3
    • 3
    LIST
  end
end

describe "Sheen::List enumerators" do
  it "alpha renders upcased letters" do
    enumerated(->Sheen::List.alpha(Sheen::Children, Int32)).should eq(<<-LIST.rstrip)
    A. Foo
    B. Bar
    C. Baz
    LIST
  end

  it "arabic renders numbers" do
    enumerated(->Sheen::List.arabic(Sheen::Children, Int32)).should eq(<<-LIST.rstrip)
    1. Foo
    2. Bar
    3. Baz
    LIST
  end

  it "roman right-aligns numerals to the widest prefix" do
    enumerated(->Sheen::List.roman(Sheen::Children, Int32)).should eq(<<-LIST.rstrip)
      I. Foo
     II. Bar
    III. Baz
    LIST
  end

  it "bullet renders bullets" do
    enumerated(->Sheen::List.bullet(Sheen::Children, Int32)).should eq(<<-LIST.rstrip)
    • Foo
    • Bar
    • Baz
    LIST
  end

  it "asterisk renders asterisks" do
    enumerated(->Sheen::List.asterisk(Sheen::Children, Int32)).should eq(<<-LIST.rstrip)
    * Foo
    * Bar
    * Baz
    LIST
  end

  it "dash renders dashes" do
    enumerated(->Sheen::List.dash(Sheen::Children, Int32)).should eq(<<-LIST.rstrip)
    - Foo
    - Bar
    - Baz
    LIST
  end
end

describe "Sheen::List enumerator values" do
  it "alpha counts in base-26 uppercase" do
    kids = Sheen::NodeChildren.new
    {0 => "A.", 25 => "Z.", 26 => "AA.", 50 => "AY.", 100 => "CW.", 701 => "ZZ.", 1000 => "ALM."}.each do |index, expected|
      Sheen::List.alpha(kids, index).should eq(expected)
    end
  end

  it "roman counts with a value-minus-one loop" do
    kids = Sheen::NodeChildren.new
    {0 => "I.", 25 => "XXVI.", 26 => "XXVII.", 50 => "LI.", 100 => "CI.", 701 => "DCCII.", 1000 => "MI."}.each do |index, expected|
      Sheen::List.roman(kids, index).should eq(expected)
    end
  end
end

describe "Sheen::List styling" do
  it "applies an enumerator style independent of items" do
    list = Sheen::List.new("foo", "bar", "baz")
      .enumerator(->Sheen::List.arabic(Sheen::Children, Int32))
      .enumerator_style(Sheen::Style.new.padding_right(1).transform(&.sub(".", ")")))
    list.render.should eq(<<-LIST.rstrip)
      1) foo
      2) bar
      3) baz
      LIST
  end

  it "applies an item style independent of enumerators" do
    list = Sheen::List.new("foo", "bar")
      .item_style(Sheen::Style.new.transform(&.upcase))
    list.render.should eq(<<-LIST.rstrip)
    • FOO
    • BAR
    LIST
  end
end
