require "../spec_helper"

private def renderer(profile : Foundation::Profile) : Sheen::Renderer
  r = Sheen::Renderer.new(IO::Memory.new)
  r.color_profile = profile
  r
end

private def style(profile : Foundation::Profile = Foundation::Profile::TrueColor) : Sheen::Style
  Sheen::Style.new(renderer(profile))
end

describe "Sheen::Style#render" do
  it "returns content untouched when no rules are set" do
    style.render("hello").should eq("hello")
  end

  it "prepends bound stringn content, joined by a space" do
    style.string("a").render("b", "c").should eq("a b c")
  end

  it "wraps  bold content in SGR 1 and a reset" do
    style.bold.render("hi").should eq("\e[1mhi\e[0m")
  end

  it "renders a truecolor foreground" do
    style.foreground("#FF0000").render("hi").should eq("\e[38;2;255;0;0mhi\e[0m")
  end

  it "renders an ANSI basic foreground, degraded by profile" do
    style(Foundation::Profile::ANSI).foreground(1).render("hi").should eq("\e[31mhi\e[0m"
    )
  end

  it "renders a bright ANSI basic foreground" do
    style(Foundation::Profile::ANSI).foreground(9).render("hi").should eq("\e[91mhi\e[0m")
  end

  it "combines attributes and colors in builder order" do
    style.bold.foreground("#FF0000").render("hi").should eq("\e[1;38;2;255;0;0mhi\e[0m")
  end

  it "renders reverse video" do
    style.reverse.render("hi").should eq("\e[7mhi\e[0m")
  end

  it "drops color under a colorless profile but keeps attributes" do
    style(Foundation::Profile::Ascii).bold.foreground("#FF0000").render("hi").should eq("\e[1mhi\e[0m")
  end

  it "styles each line independently so styling does not bleed across newlines" do
    style.bold.render("a\nb").should eq("\e[1ma\e[0m\n\e[1mb\e[0m")
  end

  it "renders bound content via to_s" do
    style.bold.string("hi").to_s.should eq("\e[1mhi\e[0m")
  end

  it "truncates by visible cells, not bytes, preserving embedded ANSI" do
    style.max_width(3).render("a\e[1mb\e[0mcd").should eq("a\e[1mb\e[0mc")
  end

  it "truncates plain content to max_width cells" do
    style.max_width(3).render("hello").should eq("hel")
  end

  it "keeps only the first max_height lines" do
    style.max_height(2).render("a\nb\nc").should eq("a\nb")
  end
end
