require "../spec_helper"

describe Sheen::Leaf do
  it "exposes its value and stringifies" do
    leaf = Sheen::Leaf.new("hello")
    leaf.value.should eq("hello")
    leaf.to_s.should eq("hello")
  end

  it "is shown by default but can be constructed as hidden" do
    Sheen::Leaf.new("x").hidden?.should be_false
    Sheen::Leaf.new("x", hidden: true).hidden?.should be_true
  end

  it "has no children" do
    Sheen::Leaf.new("x").children.length.should eq(0)
  end
end

describe Sheen::NodeChildren do
  it "appends and reads children in order" do
    children = Sheen::NodeChildren.new
    children.append(Sheen::Leaf.new("a")).append(Sheen::Leaf.new("b"))
    children.length.should eq(2)
    children.at(0).try(&.value).should eq("a")
    children.at(1).try(&.value).should eq("b")
  end

  it "returns nil for out of range indices" do
    children = Sheen::NodeChildren.new.append(Sheen::Leaf.new("a"))
    children.at(-1).should be_nil
    children.at(5).should be_nil
  end

  it "removes by index, shifting the remainder" do
    children = Sheen::NodeChildren.new
    %w(a b c).each { |v| children.append(Sheen::Leaf.new(v)) }
    children.remove(1)
    children.length.should eq(2)
    children.at(1).try(&.value).should eq("c")
  end

  it "ignores removal at an invalid index" do
    children = Sheen::NodeChildren.new.append(Sheen::Leaf.new("a"))
    children.remove(-1)
    children.remove(9)
    children.length.should eq(1)
  end
end

describe Sheen::Tree do
  it "sets a root value and appends string children" do
    tree = Sheen::Tree.root("root").child("a", "b")
    tree.value.should eq("root")
    tree.children.length.should eq(2)
    tree.children.at(0).try(&.value).should eq("a")
  end

  it "appends leaves, subtrees, and arrays to the tree" do
    sub = Sheen::Tree.root("sub").child("x")
    tree = Sheen::Tree.new.child(Sheen::Leaf.new("leaf"), sub, ["c", "d"])
    tree.children.length.should eq(4)
    tree.children.at(1).try(&.value).should eq("sub")
  end

  it "stringifies arbitrary values into children nodes" do
    Sheen::Tree.new.child(42).children.at(0).try(&.value).should eq("42")
  end

  it "Builds a tree root from another tree, adopting its values and children" do
    source = Sheen::Tree.root("src").child("x", "y")
    tree = Sheen::Tree.root(source)
    tree.value.should eq("src")
    tree.children.length.should eq(2)
  end

  it "auto-nests a rootless subtree onto the previous sibling leaf" do
    tree = Sheen::Tree.root("root").child("a", Sheen::Tree.new.child("b", "c"))
    tree.children.length.should eq(1)
    parent = tree.children.at(0)
    parent.try(&.value).should eq("a")
    parent.try(&.children.length).should eq(2)
  end

  it "returns an independent copy of children, leaving original untouched" do
    tree = Sheen::Tree.root("r").child("a")
    tree.children.as(Sheen::NodeChildren).append(Sheen::Leaf.new("b"))
    tree.children.length.should eq(1)
  end

  it "hides and unhides nodes" do
    tree = Sheen::Tree.new.hide
    tree.hidden?.should be_true
    tree.hide(false).hidden?.should be_false
  end
end

describe "Sheen::Tree enumerators and indenters" do
  it "default_enumerator branches only on the last child" do
    kids = Sheen::NodeChildren.new
    %w(a b c).each { |v| kids.append(Sheen::Leaf.new(v)) }
    Sheen::Tree.default_enumerator(kids, 0).should eq("├──")
    Sheen::Tree.default_enumerator(kids, 1).should eq("├──")
    Sheen::Tree.default_enumerator(kids, 2).should eq("└──")
  end

  it "rounded_enumerator rounds only the final corner" do
    kids = Sheen::NodeChildren.new.append(Sheen::Leaf.new("a")).append(Sheen::Leaf.new("b"))
    Sheen::Tree.rounded_enumerator(kids, 0).should eq("├──")
    Sheen::Tree.rounded_enumerator(kids, 1).should eq("╰──")
  end

  it "default_indenter continues sibling lines except under the last child" do
    kids = Sheen::NodeChildren.new.append(Sheen::Leaf.new("a")).append(Sheen::Leaf.new("b"))
    Sheen::Tree.default_indenter(kids, 0).should eq("│  ")
    Sheen::Tree.default_indenter(kids, 1).should eq("   ")
  end
end

describe "Sheen::Tree styling DSL" do
  it "carries no config until a styling setter is called" do
    Sheen::Tree.new.config.should be_nil
  end

  it "lazily builds config and returns self from a setter" do
    tree = Sheen::Tree.new
    tree.enumerator_style(Sheen::Style.new.bold).should be(tree)
    tree.config.should_not be_nil
  end

  it "applies a static enumerator style at every position" do
    tree = Sheen::Tree.root("r").child("a", "b").enumerator_style(Sheen::Style.new.bold)
    config = tree.config.not_nil! # ameba:disable Lint/NotNil
    kids = tree.children
    config.enumerator_style_picker.call(kids, 0).bold?.should be_true
    config.enumerator_style_picker.call(kids, 1).bold?.should be_true
  end

  it "invokes an enumerator style block per index" do
    tree = Sheen::Tree.root("r").child("a", "b").enumerator_style do |_children, i|
      i.zero? ? Sheen::Style.new.bold : Sheen::Style.new.faint
    end

    config = tree.config.not_nil! # ameba:disable Lint/NotNil
    kids = tree.children
    config.enumerator_style_picker.call(kids, 0).bold?.should be_true
    config.enumerator_style_picker.call(kids, 1).faint?.should be_true
  end

  it "stores item style, root style, customer enumerator, and indenter" do
    tree = Sheen::Tree.new
      .item_style(Sheen::Style.new.italic)
      .root_style(Sheen::Style.new.underline)
      .enumerator(->Sheen::Tree.rounded_enumerator(Sheen::Children, Int32))
      .indenter(->(_c : Sheen::Children, _i : Int32) { ">> " })
    config = tree.config.not_nil! # ameba:disable Lint/NotNil
    kids = Sheen::NodeChildren.new.append(Sheen::Leaf.new("x"))
    config.item_style_picker.call(kids, 0).italic?.should be_true
    config.root_style.underline?.should be_true
    config.enumerator.call(kids, 0).should eq("╰──")
    config.indenter.call(kids, 0).should eq(">> ")
  end

  it "seeds the default enumerator style with a trailing pad" do
    config = Sheen::TreeStyle.new
    kids = Sheen::NodeChildren.new.append(Sheen::Leaf.new("x"))
    config.enumerator_style_picker.call(kids, 0).padding_right.should eq(1)
  end
end
