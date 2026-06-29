require "../spec_helper"

private def renderer : Sheen::Renderer
  r = Sheen::Renderer.new(IO::Memory.new)
  r.color_profile = Foundation::Profile::TrueColor
  r
end

private def style : Sheen::Style
  Sheen::Style.new(renderer)
end

describe "Sheen::Style#render - normalization" do
  describe "tab expansion" do
    it "expands tabs to 4 spaces by default" do
      style.render("a\tb").should eq("a    b")
    end

    it "honors an explicit tab width" do
      style.tab_width(2).render("a\tb").should eq("a  b")
    end

    it "strips tabs when tab width is 0" do
      style.tab_width(0).render("a\tb").should eq("ab")
    end

    it "leaves tabs intact under NO_TAB_CONVERSION" do
      style.tab_width(Sheen::Style::NO_TAB_CONVERSION).render("a\tb").should eq("a\tb")
    end

    it "expands tabs even when no stule rules are set" do
      Sheen::Style.new.render("a\tb").should eq("a    b")
    end
  end

  it "normalizes CRLF to LF" do
    style.render("a\r\nb").should eq("a\nb")
  end

  describe "inline mode" do
    it "strips newlines" do
      style.inline.render("a\nb").should eq("ab")
    end

    it "keeps a single styled line under styling" do
      style.inline.bold.render("a\nb").should eq("\e[1mab\e[0m")
    end
  end

  describe "width word-wrap" do
    it "wraps content to the width" do
      style.width(5).render("hello world").should eq("hello\nworld")
    end

    it "subtracts horizontal padding from the wrap point" do
      style.width(8).padding(0, 2).render("aaaa bbbb").should eq("aaaa\nbbbb")
    end

    it "does not wrap in inline mode" do
      style.inline.width(5).render("hello world").should eq("hello world")
    end
  end
end
