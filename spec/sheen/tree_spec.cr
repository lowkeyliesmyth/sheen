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
