require "../spec_helper"

# Covers construction, setters/getters, CSS style shorthand around layouts

describe Sheen::Style do
  it "starts empty" do
    sty = Sheen::Style.new
    sty.bold?.should be_false
    sty.foreground.should eq(Sheen::NoColor.new)
    sty.value.should eq("")
  end

  it "returns a new Style from each setter leaving the original unchanged" do
    base = Sheen::Style.new
    bold = base.bold
    base.bold?.should be_false
    bold.bold?.should be_true
  end

  it "records an explicitly disabled boolean as being 'set' but 'turned off'" do
    Sheen::Style.new.bold(false).bold?.should be_false
  end

  it "supports every bool formatting setter" do
    sty = Sheen::Style.new.bold.faint.italic.underline.strikethrough.reverse.blink
    sty.bold?.should be_true
    sty.faint?.should be_true
    sty.italic?.should be_true
    sty.underline?.should be_true
    sty.strikethrough?.should be_true
    sty.reverse?.should be_true
    sty.blink?.should be_true
  end

  it "stores foreground and background colors" do
    sty = Sheen::Style.new.foreground("#FF0000").background(4)
    sty.foreground.should eq(Sheen::Color.new("#FF0000"))
    sty.background.should eq(Sheen::ANSIColor.new(4))
  end

  it "accepts a color instance for foreground" do
    sty = Sheen::Style.new.foreground(Sheen::RED)
    sty.foreground.should eq(Sheen::RED)
    sty.foreground.should eq(Sheen::ANSIColor.new(1))
  end

  it "stores max width and height" do
    sty = Sheen::Style.new.max_width(10).max_height(3)
    sty.max_width.should eq(10)
    sty.max_height.should eq(3)
  end

  it "binds content via string and reads it back via value" do
    sty = Sheen::Style.new.string("hello", "world")
    sty.value.should eq("hello world")
  end

  it "rebinds to a different explicitly provided renderer" do
    other = Sheen::Renderer.new(IO::Memory.new)
    sty = Sheen::Style.new.renderer(other)
    sty.renderer.should be(other)
  end

  it "is chain-order independent" do
    first = Sheen::Style.new.bold.foreground("#FF0000")
    second = Sheen::Style.new.foreground("#FF0000").bold
    first.bold?.should eq(second.bold?)
    first.foreground.should eq(second.foreground)
  end

  describe "Sheen.style block builder" do
    it "produces a Style equivalent to the fluent chain" do
      built = Sheen.style { |sty| sty.bold; sty.foreground("#7D56F4") }
      built.bold?.should be_true
      built.foreground.should eq(Sheen::Color.new("#7D56F4"))
    end

    it "chains within the block" do
      # ameba:disable Style/VerboseBlock
      built = Sheen.style { |sty| sty.bold.italic.max_width(8) }
      built.italic?.should be_true
      built.max_width.should eq(8)
    end
  end
end

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

  describe "borders" do
    it "defaults to no border" do
      Sheen::Style.new.border_style.none?.should be_true
      Sheen::Style.new.horizontal_border_size.should eq(0)
      Sheen::Style.new.vertical_border_size.should eq(0)
    end

    it "sets a border on all sides by default" do
      sty = Sheen::Style.new.border(Sheen::Border.normal)
      sty.border_style.should eq(Sheen::Border.normal)
      {sty.border_top?, sty.border_right?, sty.border_bottom?, sty.border_left?}.should eq({true, true, true, true})
    end

    it "sets sides via CSS style shorthand" do
      sty = Sheen::Style.new.border(Sheen::Border.normal, true, false)
      {sty.border_top?, sty.border_right?, sty.border_bottom?, sty.border_left?}.should eq({true, false, true, false})
    end

    it "raises on more than four side values" do
      expect_raises(ArgumentError) do
        Sheen::Style.new.border(Sheen::Border.normal, true, true, true, true, true)
      end
    end

    it "toggles a single side" do
      sty = Sheen::Style.new.border_left(true)
      sty.border_left?.should be_true
      sty.border_right?.should be_false
    end

    describe "implicit borders" do
      it "is true when a style is set with no side toggles" do
        Sheen::Style.new.border_style(Sheen::Border.normal).implicit_borders?.should be_true
      end

      it "is false once any side is toggled" do
        Sheen::Style.new.border_style(Sheen::Border.normal).border_top(false).implicit_borders?.should be_false
      end

      it "is false when set via #border, since sides are explicit" do
        Sheen::Style.new.border(Sheen::Border.normal).implicit_borders?.should be_false
      end
    end

    describe "colors" do
      it "sets all four foregrounds from one value" do
        sty = Sheen::Style.new.border_foreground(Sheen::RED)
        {sty.border_top_foreground, sty.border_right_foreground, sty.border_bottom_foreground, sty.border_left_foreground}.should eq({Sheen::RED, Sheen::RED, Sheen::RED, Sheen::RED})
      end

      it "sets vertical/horizontal foregrounds from two values" do
        sty = Sheen::Style.new.border_foreground(Sheen::RED, Sheen::BLUE)
        sty.border_top_foreground.should eq(Sheen::RED)
        sty.border_right_foreground.should eq(Sheen::BLUE)
        sty.border_bottom_foreground.should eq(Sheen::RED)
        sty.border_left_foreground.should eq(Sheen::BLUE)
      end

      it "sets a single side background" do
        Sheen::Style.new.border_top_background("#FF0000").border_top_background
          .should eq(Sheen::Color.new("#FF0000"))
      end
    end

    describe "size getters" do
      it "reports edge sizes when a border is present" do
        sty = Sheen::Style.new.border(Sheen::Border.normal)
        sty.border_top_size.should eq(1)
        sty.horizontal_border_size.should eq(2)
        sty.vertical_border_size.should eq(2)
      end

      it "reports 0 for an explicitly disabled side" do
        Sheen::Style.new.border_style(Sheen::Border.normal).border_top(false).border_top_size.should eq(0)
      end

      it "folds border into the frame size" do
        sty = Sheen::Style.new.padding(1).border(Sheen::Border.normal)
        sty.horizontal_frame_size.should eq(4)
        sty.vertical_frame_size.should eq(4)
      end
    end
  end

  it "sets a single padding side" do
    sty = Sheen::Style.new.padding_left(5)
    sty.padding_left.should eq(5)
    sty.padding_right.should eq(0)
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

  it "stores width and height" do
    sty = Sheen::Style.new.width(20).height(5)
    sty.width.should eq(20)
    sty.height.should eq(5)
  end
end

describe "Sheen::Style#unset_" do
  it "returns a property to the unset state" do
    sty = Sheen::Style.new.bold.unset_bold
    sty.bold_set?.should be_false
    sty.bold?.should be_false
  end

  it "makes a property inheritable again" do
    sty = Sheen::Style.new.bold(false).unset_bold
    sty.inherit(Sheen::Style.new.bold).bold?.should be_true
  end

  it "unsets a color" do
    Sheen::Style.new.foreground("#FF0000").unset_foreground.foreground_set?.should be_false
  end

  it "unsets all padding sides" do
    sty = Sheen::Style.new.padding(2).unset_padding
    {sty.padding_top_set?, sty.padding_right_set?, sty.padding_bottom_set?, sty.padding_left_set?}
      .should eq({false, false, false, false})
  end

  it "unsets both alignment axes" do
    sty = Sheen::Style.new.align(Sheen::Position::CENTER, Sheen::Position::BOTTOM).unset_align
    sty.align_horizontal_set?.should be_false
    sty.align_vertical_set?.should be_false
  end

  it "unsets all border foreground colors" do
    sty = Sheen::Style.new.border_foreground(Sheen::RED).unset_border_foreground
    sty.border_top_foreground_set?.should be_false
    sty.border_left_foreground_set?.should be_false
  end

  it "clears the bound string value" do
    Sheen::Style.new.string("hi").unset_string.value.should eq("")
  end

  it "returns the tab width to its default" do
    Sheen::Style.new.tab_width(2).unset_tab_width.tab_width.should eq(4)
  end
end

describe "Sheen::Style#inherit" do
  it "adopts a property the other style has set but this one hasn't" do
    Sheen::Style.new.inherit(Sheen::Style.new.bold).bold?.should be_true
  end

  it "keeps this style's own set property over the others'" do
    base = Sheen::Style.new.foreground("#FF0000")
    base.inherit(Sheen::Style.new.foreground("#00FF00")).foreground.should eq(Sheen::Color.new("#FF0000"))
  end

  it "respects an explicitly disabled property" do
    inherited = Sheen::Style.new.bold(false).inherit(Sheen::Style.new.bold)
    inherited.bold?.should be_false
    inherited.bold_set?.should be_true
  end

  it "does not inherit padding" do
    Sheen::Style.new.inherit(Sheen::Style.new.padding(2)).padding_top_set?.should be_false
  end

  it "does not inherit margins" do
    Sheen::Style.new.inherit(Sheen::Style.new.margin(2)).margin_top_set?.should be_false
  end

  it "does not inherit the bound string value" do
    Sheen::Style.new.inherit(Sheen::Style.new.string("x")).value.should eq("")
  end

  it "seeds the margin background from an inherited background" do
    Sheen::Style.new.inherit(Sheen::Style.new.background("#FF0000")).margin_background
      .should eq(Sheen::Color.new("#FF0000"))
  end

  it "does not seed the margin background when this style already has one" do
    Sheen::Style.new.margin_background("#0000FF").inherit(Sheen::Style.new.background("#FF0000")).margin_background
      .should eq(Sheen::Color.new("#0000FF"))
  end
end
