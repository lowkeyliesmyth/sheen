require "../spec_helper"

private def renderer : Sheen::Renderer
  rnd = Sheen::Renderer.new(IO::Memory.new)
  rnd.color_profile = Foundation::Profile::TrueColor
  rnd
end

private def style : Sheen::Style
  Sheen::Style.new(renderer)
end

describe "Sheen::Style#render - block shaping" do
  describe "horizontal alignment to width" do
    it "left-aligns by default, padding the right" do
      style.width(10).render("hi").should eq("hi" + " " * 8)
    end

    it "right-aligns, padding the left" do
      style.width(10).align_horizontal(Sheen::Position::RIGHT).render("hi")
        .should eq(" " * 8 + "hi")
    end

    it "centers, with the odd remainder on the right" do
      style.width(5).align_horizontal(Sheen::Position::CENTER).render("hi")
        .should eq(" hi  ")
    end
  end

  it "makes a multiline block rectangular without requiring an explicit width" do
    style.render("a\nbbb").should eq("a  \nbbb")
  end

  describe "padding" do
    it "pads left and right" do
      style.padding(0, 2).render("hi").should eq("  hi  ")
    end

    it "pads top and bottom, then pads out the blank lines to match width" do
      style.padding(1, 0).render("hi").should eq("  \nhi\n  ")
    end
  end

  describe "vertical fill to height" do
    it "top-aligns by default" do
      style.height(3).render("hi").should eq("hi\n  \n  ")
    end

    it "centers vertically" do
      style.height(3).align_vertical(Sheen::Position::CENTER).render("hi")
        .should eq("  \nhi\n  ")
    end

    it "bottom aligns" do
      style.height(3).align_vertical(Sheen::Position::BOTTOM).render("hi")
        .should eq("  \n  \nhi")
    end
  end

  it "styles alignment whitespace with the background color" do
    style.width(4).background(Sheen::RED).render("hi")
      .should eq("\e[41mhi\e[0m\e[41m  \e[0m")
  end
end
