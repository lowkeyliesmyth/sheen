require "../spec_helper"

describe "Sheen::Style layout properties" do
  describe "padding shorthand" do
    it "expands one value to all sides" do
      sty = Sheen::Style.new.padding(2)
      {sty.padding_top, sty.padding_right, sty.padding_bottom, sty.padding_left}.should eq({2, 2, 2, 2})
    end

    it "expands two values to vertical+horizontal" do
      sty = Sheen::Style.new.padding(1, 2)
      {sty.padding_top, sty.padding_right, sty.padding_bottom, sty.padding_left}.should eq({1, 2, 1, 2})
    end

    it "expands three values to top+horizontal+bottom" do
      sty = Sheen::Style.new.padding(1, 2, 3)
      {sty.padding_top, sty.padding_right, sty.padding_bottom, sty.padding_left}.should eq({1, 2, 3, 2})
    end

    it "expands four values clockwise" do
      sty = Sheen::Style.new.padding(1, 2, 3, 4)
      {sty.padding_top, sty.padding_right, sty.padding_bottom, sty.padding_left}.should eq({1, 2, 3, 4})
    end

    it "raises on an invalid value arg count" do
      expect_raises(ArgumentError, "1-4") do
        Sheen::Style.new.padding(1, 2, 3, 4, 5)
      end
    end
  end

  it "sets a single padding side" do
    sty = Sheen::Style.new.padding_left(5)
    sty.padding_left.should eq(5)
    sty.padding_right.should eq(0)
  end

  describe "margins" do
    it "expand via the same CSS shorthand as padding" do
      sty = Sheen::Style.new.margin(1, 2)
      {sty.margin_top, sty.margin_right, sty.margin_bottom, sty.margin_left}.should eq({1, 2, 1, 2})
    end

    it "carry a background color" do
      Sheen::Style.new.margin_background("#FF0000").margin_background.should eq(Sheen::Color.new("#FF0000"))
    end

    it "default to no background" do
      Sheen::Style.new.margin_background.should eq(Sheen::NoColor.new)
    end
  end

  it "stores width and height" do
    sty = Sheen::Style.new.width(20).height(5)
    sty.width.should eq(20)
    sty.height.should eq(5)
  end

  describe "alignment" do
    it "sets horizontal alignment alone, leaving vertical at the default" do
      sty = Sheen::Style.new.align(Sheen::Position::CENTER)
      sty.align_horizontal.should eq(Sheen::Position::CENTER)
      sty.align_vertical.should eq(Sheen::Position::TOP)
    end

    it "sets both axes" do
      sty = Sheen::Style.new.align(Sheen::Position::RIGHT, Sheen::Position::BOTTOM)
      sty.align_horizontal.should eq(Sheen::Position::RIGHT)
      sty.align_vertical.should eq(Sheen::Position::BOTTOM)
    end

    it "sets each axis independently" do
      sty = Sheen::Style.new.align_horizontal(Sheen::Position::CENTER).align_vertical(Sheen::Position::BOTTOM)
      sty.align_horizontal.should eq(Sheen::Position::CENTER)
      sty.align_horizontal.should eq(Sheen::Position.new(0.5))
      sty.align_vertical.should eq(Sheen::Position::BOTTOM)
      sty.align_vertical.should eq(Sheen::Position.new(1.0))
    end
  end

  describe "inline" do
    it "defaults to unset, and distinguishes between unset and explicitly off" do
      Sheen::Style.new.inline_set?.should be_false
      Sheen::Style.new.inline?.should be_false

      off = Sheen::Style.new.inline(false)
      off.inline_set?.should be_true
      off.inline?.should be_false

      on = Sheen::Style.new.inline
      on.inline_set?.should be_true
      on.inline?.should be_true
    end
  end

  describe "tab width" do
    it "defaults to 4" do
      Sheen::Style.new.tab_width.should eq(4)
    end

    it "stores an explicit width" do
      Sheen::Style.new.tab_width(2).tab_width.should eq(2)
    end

    it "accepts the no-conversion sentinel" do
      Sheen::Style.new.tab_width(Sheen::Style::NO_TAB_CONVERSION)
    end
  end

  it "sums padding and margins into frame sizes" do
    sty = Sheen::Style.new.padding(1, 2, 3, 4).margin(5, 6, 7, 8)
    sty.horizontal_padding.should eq(6)
    sty.vertical_padding.should eq(4)
    sty.horizontal_margins.should eq(14)
    sty.vertical_margins.should eq(12)
    sty.horizontal_frame_size.should eq(20)
    sty.vertical_frame_size.should eq(16)
    sty.frame_size.should eq({20, 16})
  end
end

describe Sheen::Position do
  it "clamps fractions into 0.0..1.0 range" do
    Sheen::Position.new(-0.5).fraction.should eq(0.0)
    Sheen::Position.new(1.5).fraction.should eq(1.0)
    Sheen::Position.new(0.25).fraction.should eq(0.25)
  end

  it "names the cardinal positions" do
    Sheen::Position::LEFT.value.should eq(0.0)
    Sheen::Position::TOP.value.should eq(0.0)
    Sheen::Position::RIGHT.value.should eq(1.0)
    Sheen::Position::BOTTOM.value.should eq(1.0)
    Sheen::Position::CENTER.value.should eq(0.5)
  end
end
