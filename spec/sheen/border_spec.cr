require "../spec_helper"

describe Sheen::Border do
  it "exposes the normal border's pieces" do
    b = Sheen::Border.normal
    b.top.should eq("─")
    b.top_left.should eq("┌")
    b.bottom_right.should eq("┘")
    b.middle.should eq("┼")
  end

  it "has round corners in the rounded border" do
    b = Sheen::Border.rounded
    b.top_left.should eq("╭")
    b.bottom_right.should eq("╯")
  end

  it "builds ASCII-only borders" do
    b = Sheen::Border.ascii
    b.top.should eq("-")
    b.top_left.should eq("+")
  end

  it "builds outer half-block borders with empty middle pieces" do
    Sheen::Border.outer_half_block.middle.should eq("")
  end

  describe "edge sizes" do
    it "reports a width of 1 for each visible edge" do
      b = Sheen::Border.double
      {b.top_size, b.right_size, b.bottom_size, b.left_size}.should eq({1, 1, 1, 1})
    end

    it "reports 0 for an absent edge" do
      Sheen::Border.new.top_size.should eq(0)
    end
  end

  describe "#none?" do
    it "is true for an all-empty border" do
      Sheen::Border.new.none?.should be_true
    end

    it "is false for a built border" do
      Sheen::Border.normal.none?.should be_false
    end
  end

  it "compares by value" do
    Sheen::Border.normal.should eq(Sheen::Border.normal)
    Sheen::Border.normal.should_not eq(Sheen::Border.thick)
  end
end
