require "../spec_helper"

describe Sheen::Style do
  it "starts empty" do
    sty = Sheen::Style.new
    sty.bold?.should be_false
    sty.set?(Sheen::Style::Prop::Bold).should be_false
    sty.foreground.should eq(Sheen::NoColor.new)
    sty.value.should eq("")
  end

  it "returns a new Style from each setter leaving the original unchanged" do
    base = Sheen::Style.new
    bold = base.bold
    base.bold?.should be_false
    bold.bold?.should be_true
    bold.should_not be(base)
  end

  it "records an explicitly disabled boolean as being 'set' but 'turned off'" do
    sty = Sheen::Style.new.bold(false)
    sty.bold?.should be_false
    sty.set?(Sheen::Style::Prop::Bold).should be_true
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
