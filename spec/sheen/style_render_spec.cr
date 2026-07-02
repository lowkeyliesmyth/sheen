require "../spec_helper"

# Test helper.
# Creates a stub `Sheen::Renderer` writing to a null buffer, bound to the given color *profile*.
private def renderer(profile : Foundation::Profile) : Sheen::Renderer
  rnd = Sheen::Renderer.new(IO::Memory.new)
  rnd.color_profile = profile
  rnd
end

# Test helper.
# Returns a new `Sheen::Style` bound to a stub renderer using the given color *profile*.
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
      # 8 cells - 4 of horiz padding wraps content at 4  chars =  this wraps to two lines
      style.width(8).padding(0, 2).render("aa bb").should eq("  aa    \n  bb    ")
      # same width with no padding keeps all 8 cells, so doesn't wrap
      style.width(8).render("aa bb").should eq("aa bb   ")
    end

    it "does not wrap in inline mode" do
      style.inline.width(5).render("hello world").should eq("hello world")
    end
  end
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
  describe "margins" do
    it "adds left and right margins" do
      style.margin(0, 2).render("hi").should eq("  hi  ")
    end

    it "fills L+R margin space with the margin background" do
      style.margin(0, 2).margin_background(Sheen::RED).render("hi")
        .should eq("\e[41m  \e[0mhi\e[41m  \e[0m")
    end

    it "adds top and bottom margins as full width blank lines" do
      style.margin(1, 0).render("hi").should eq("  \nhi\n  ")
    end

    it "spans T+B margins across the full block width" do
      style.margin(1, 0).render("a\nbbb").should eq("   \na  \nbbb\n   ")
    end

    it "ignores margins in inline mode" do
      style.inline.margin(1, 2).render("hi").should eq("hi")
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

describe "Sheen::Style#render - borders" do
  it "draws a normal border around single-line content" do
    style.border(Sheen::Border.normal).render("hi").should eq("┌──┐\n│hi│\n└──┘")
  end

  it "draws a rounded border" do
    style.border(Sheen::Border.rounded).render("hi").should eq("╭──╮\n│hi│\n╰──╯")
  end
  it "draws only the sides that are enabled" do
    style.border(Sheen::Border.normal, true, false, false, false).render("hi")
      .should eq("──\nhi")
  end

  it "selects only the corners whose adjacent sides are shows" do
    style.border(Sheen::Border.normal, true, false, false, true).render("hi")
      .should eq("┌──\n│hi")
  end

  it "colors the border without bleeding into the content" do
    style.border(Sheen::Border.normal).border_foreground(Sheen::RED).render("hi")
      .should eq("\e[31m┌──┐\e[0m\n\e[31m│\e[0mhi\e[31m│\e[0m\n\e[31m└──┘\e[0m")
  end

  it "sits outside padding and inside the target width" do
    style.width(4).padding(0, 1).border(Sheen::Border.normal).render("hi")
      .should eq("┌────┐\n│ hi │\n└────┘")
  end

  it "is ignored in inline mode" do
    style.inline.border(Sheen::Border.normal).render("hi")
      .should eq("hi")
  end
end
