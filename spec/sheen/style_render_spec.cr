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

# Test helper.
# Renders *strings* through *style* by driving the `StylePainter` directly.
private def render(style : Sheen::Style, *strings : String) : String
  Sheen::StylePainter.new(style).render(strings.to_a)
end

describe "Sheen::StylePainter#render" do
  it "returns content untouched when no rules are set" do
    render(style, "hello").should eq("hello")
  end

  it "prepends bound string content, joined by a space" do
    render(style.string("a"), "b", "c").should eq("a b c")
  end

  it "wraps  bold content in SGR 1 and a reset" do
    render(style.bold, "hi").should eq("\e[1mhi\e[0m")
  end

  it "renders a truecolor foreground" do
    render(style.foreground("#FF0000"), "hi").should eq("\e[38;2;255;0;0mhi\e[0m")
  end

  it "renders an ANSI basic foreground, degraded by profile" do
    render(style(Foundation::Profile::ANSI).foreground(1), "hi").should eq("\e[31mhi\e[0m")
  end

  it "renders a bright ANSI basic foreground" do
    render(style(Foundation::Profile::ANSI).foreground(9), "hi").should eq("\e[91mhi\e[0m")
  end

  it "combines attributes and colors in builder order" do
    render(style.bold.foreground("#FF0000"), "hi").should eq("\e[1;38;2;255;0;0mhi\e[0m")
  end

  it "renders reverse video" do
    render(style.reverse, "hi").should eq("\e[7mhi\e[0m")
  end

  it "drops color under a colorless profile but keeps attributes" do
    render(style(Foundation::Profile::Ascii).bold.foreground("#FF0000"), "hi").should eq("\e[1mhi\e[0m")
  end

  it "styles each line independently so styling does not bleed across newlines" do
    render(style.bold, "a\nb").should eq("\e[1ma\e[0m\n\e[1mb\e[0m")
  end

  it "truncates by visible cells, not bytes, preserving embedded ANSI" do
    render(style.max_width(3), "a\e[1mb\e[0mcd").should eq("a\e[1mb\e[0mc")
  end

  it "truncates plain content to max_width cells" do
    render(style.max_width(3), "hello").should eq("hel")
  end

  it "keeps only the first max_height lines" do
    render(style.max_height(2), "a\nb\nc").should eq("a\nb")
  end
end

describe "Sheen::StylePainter#render - normalization" do
  describe "tab expansion" do
    it "expands tabs to 4 spaces by default" do
      render(style, "a\tb").should eq("a    b")
    end

    it "honors an explicit tab width" do
      render(style.tab_width(2), "a\tb").should eq("a  b")
    end

    it "strips tabs when tab width is 0" do
      render(style.tab_width(0), "a\tb").should eq("ab")
    end

    it "leaves tabs intact under NO_TAB_CONVERSION" do
      render(style.tab_width(Sheen::Style::NO_TAB_CONVERSION), "a\tb").should eq("a\tb")
    end

    it "expands tabs even when no stule rules are set" do
      render(Sheen::Style.new, "a\tb").should eq("a    b")
    end
  end

  it "normalizes CRLF to LF" do
    render(style, "a\r\nb").should eq("a\nb")
  end

  describe "inline mode" do
    it "strips newlines" do
      render(style.inline, "a\nb").should eq("ab")
    end

    it "keeps a single styled line under styling" do
      render(style.inline.bold, "a\nb").should eq("\e[1mab\e[0m")
    end
  end

  describe "width word-wrap" do
    it "wraps content to the width" do
      render(style.width(5), "hello world").should eq("hello\nworld")
    end

    it "subtracts horizontal padding from the wrap point" do
      # 8 cells - 4 of horiz padding wraps content at 4  chars =  this wraps to two lines
      render(style.width(8).padding(0, 2), "aa bb").should eq("  aa    \n  bb    ")
      # same width with no padding keeps all 8 cells, so doesn't wrap
      render(style.width(8), "aa bb").should eq("aa bb   ")
    end

    it "does not wrap in inline mode" do
      render(style.inline.width(5), "hello world").should eq("hello world")
    end
  end
end

describe "Sheen::StylePainter#render - block shaping" do
  describe "horizontal alignment to width" do
    it "left-aligns by default, padding the right" do
      render(style.width(10), "hi").should eq("hi" + " " * 8)
    end

    it "right-aligns, padding the left" do
      render(style.width(10).align_horizontal(Sheen::Position::RIGHT), "hi")
        .should eq(" " * 8 + "hi")
    end

    it "centers, with the odd remainder on the right" do
      render(style.width(5).align_horizontal(Sheen::Position::CENTER), "hi")
        .should eq(" hi  ")
    end
  end

  it "makes a multiline block rectangular without requiring an explicit width" do
    render(style, "a\nbbb").should eq("a  \nbbb")
  end

  describe "padding" do
    it "pads left and right" do
      render(style.padding(0, 2), "hi").should eq("  hi  ")
    end

    it "pads top and bottom, then pads out the blank lines to match width" do
      render(style.padding(1, 0), "hi").should eq("  \nhi\n  ")
    end
  end

  describe "margins" do
    it "adds left and right margins" do
      render(style.margin(0, 2), "hi").should eq("  hi  ")
    end

    it "fills L+R margin space with the margin background" do
      render(style.margin(0, 2).margin_background(Sheen::RED), "hi")
        .should eq("\e[41m  \e[0mhi\e[41m  \e[0m")
    end

    it "adds top and bottom margins as full width blank lines" do
      render(style.margin(1, 0), "hi").should eq("  \nhi\n  ")
    end

    it "spans T+B margins across the full block width" do
      render(style.margin(1, 0), "a\nbbb").should eq("   \na  \nbbb\n   ")
    end

    it "ignores margins in inline mode" do
      render(style.inline.margin(1, 2), "hi").should eq("hi")
    end
  end

  describe "vertical fill to height" do
    it "top-aligns by default" do
      render(style.height(3), "hi").should eq("hi\n  \n  ")
    end

    it "centers vertically" do
      render(style.height(3).align_vertical(Sheen::Position::CENTER), "hi")
        .should eq("  \nhi\n  ")
    end

    it "bottom aligns" do
      render(style.height(3).align_vertical(Sheen::Position::BOTTOM), "hi")
        .should eq("  \n  \nhi")
    end
  end

  it "styles alignment whitespace with the background color" do
    render(style.width(4).background(Sheen::RED), "hi")
      .should eq("\e[41mhi\e[0m\e[41m  \e[0m")
  end
end

describe "Sheen::StylePainter#render - borders" do
  it "draws a normal border around single-line content" do
    render(style.border(Sheen::Border.normal), "hi").should eq("┌──┐\n│hi│\n└──┘")
  end

  it "draws a rounded border" do
    render(style.border(Sheen::Border.rounded), "hi").should eq("╭──╮\n│hi│\n╰──╯")
  end

  it "draws only the sides that are enabled" do
    render(style.border(Sheen::Border.normal, true, false, false, false), "hi")
      .should eq("──\nhi")
  end

  it "selects only the corners whose adjacent sides are shows" do
    render(style.border(Sheen::Border.normal, true, false, false, true), "hi")
      .should eq("┌──\n│hi")
  end

  it "colors the border without bleeding into the content" do
    render(style.border(Sheen::Border.normal).border_foreground(Sheen::RED), "hi")
      .should eq("\e[31m┌──┐\e[0m\n\e[31m│\e[0mhi\e[31m│\e[0m\n\e[31m└──┘\e[0m")
  end

  it "sits outside padding and inside the target width" do
    render(style.width(4).padding(0, 1).border(Sheen::Border.normal), "hi")
      .should eq("┌────┐\n│ hi │\n└────┘")
  end

  it "is ignored in inline mode" do
    render(style.inline.border(Sheen::Border.normal), "hi").should eq("hi")
  end

  it "Fills a multi-width border edge to the body width" do
    # top fill cycles 口(2 cells) + x(1 cell); every other piece is single-width.
    border = Sheen::Border.new(
      top: "口x",
      bottom: "-",
      left: "|",
      right: "|",
      top_left: "+",
      top_right: "+",
      bottom_left: "+",
      bottom_right: "+",
    )
    # Body is "|hi|" = 4 cells, so the top edge must also be 4 cells: "+口+".
    render(style.border(border), "hi").should eq("+口+\n|hi|\n+--+")
    render(style.border(border), "hey").should eq("+口x+\n|hey|\n+---+")
    render(style.border(border), "hola").should eq("+口x口+\n|hola|\n+----+")
  end
end

describe "Sheen::Style render delegation" do
  it "renders through Style#render" do
    style.bold.render("hi").should eq("\e[1mhi\e[0m")
  end

  it "renders bound content through Style#to_s" do
    style.bold.string("hi").to_s.should eq("\e[1mhi\e[0m")
  end
end

describe "Sheen::StylePainter#render - transform" do
  it "applies a transform to the assembled content" do
    render(style.transform(&.upcase), "hi").should eq("HI")
  end

  it "runs the transform before the SGR wrap" do
    render(style.bold.transform(&.upcase), "hi").should eq("\e[1mHI\e[0m")
  end

  it "transforms the joined value and arguments together" do
    render(style.string("a").transform(&.upcase), "b").should eq("A B")
  end

  it "applies a transform set through the Sheen.style builder" do
    built = Sheen.style(renderer(Foundation::Profile::TrueColor)) { |sty| sty.bold.transform(&.upcase) }
    render(built, "hi").should eq("\e[1mHI\e[0m")
  end
end

describe "Sheen::StylePainter#render - space styling" do
  it "styles each run individually under plain underline, including spaces" do
    render(style.underline, "a b").should eq("\e[4ma\e[0m\e[4m \e[0m\e[4mb\e[0m")
  end

  it "leaves spaces unstyled when underline_spaces is off" do
    render(style.underline.underline_spaces(false), "a b").should eq("\e[4ma\e[0m \e[4mb\e[0m")
  end

  it "leaves spaces unstyled when strikethrough_spaces is off" do
    render(style.strikethrough.strikethrough_spaces(false), "a b").should eq("\e[9ma\e[0m \e[9mb\e[0m")
  end

  it "stops the background from bleeding into fill when color_whitespace is set to off" do
    render(style.width(4).background(Sheen::RED).color_whitespace(false), "hi")
      .should eq("\e[41mhi\e[0m  ")
  end

  it "carries the foreground into reverse fill" do
    render(style.width(4).reverse.foreground(Sheen::RED), "hi")
      .should eq("\e[7;31mhi\e[0m\e[7;31m  \e[0m")
  end
end
