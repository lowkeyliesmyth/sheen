require "../spec_helper"

describe "Sheen measurement" do
  it "measures width as the widest line" do
    Sheen.width("hi\nthere").should eq(5)
  end

  it "ignores ANSI when measuring width" do
    Sheen.width("\e[1mhi\e[0m").should eq(2)
  end

  it "measures height by line count" do
    Sheen.height("a\nb\nc").should eq(3)
  end

  it "measures size as width and height" do
    Sheen.size("hi\nthere").should eq({5, 2})
  end
end

describe "Sheen.join_horizontal" do
  it "returns the single block unchanged" do
    Sheen.join_horizontal(Sheen::Position::TOP, "solo").should eq("solo")
  end

  it "joins side by side, top aligned" do
    Sheen.join_horizontal(Sheen::Position::TOP, "AAA\nAAA", "B")
      .should eq("AAAB\nAAA ")
  end

  it "joins side by side, bottom-aligned" do
    Sheen.join_horizontal(Sheen::Position::BOTTOM, "AAA\nAAA", "B")
      .should eq("AAA \nAAAB")
  end
end

describe "Sheen.join_vertical" do
  it "stacks blocks, left aligned" do
    Sheen.join_vertical(Sheen::Position::LEFT, "AA", "BBBB")
      .should eq("AA  \nBBBB")
  end

  it "stacks blocks, right aligned" do
    Sheen.join_vertical(Sheen::Position::RIGHT, "AA", "BBBB")
      .should eq("  AA\nBBBB")
  end

  it "stacks blocks, centered" do
    Sheen.join_vertical(Sheen::Position::CENTER, "CCCC", "DD")
      .should eq("CCCC\n DD ")
  end
end
