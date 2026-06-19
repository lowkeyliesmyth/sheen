require "../spec_helper"

describe "#strip" do
  it "returns plain strings unchanged" do
    Foundation.strip("hello").should eq("hello")
  end

  it "removes SGR sequences" do
    Foundation.strip("\e[1;31mred\e[0m").should eq("red")
  end

  it "removes OSC hyperlink sequences" do
    Foundation.strip("\e]8;;https://example.com\e\\click\e]8;;\e\\").should eq("click")
  end

  it "removes OSC terminated by BEL" do
    Foundation.strip("\e]0;title\atext").should eq("text")
  end

  it "removes two-byte ESX sequences" do
    Foundation.strip("a\eMb").should eq("ab")
  end

  it "handless strings with no esxapes and unicode content" do
    Foundation.strip("héllo 世界 🎉").should eq("héllo 世界 🎉")
  end

  it "strips back to back sequences without gobbling printable text between" do
    Foundation.strip("\e[1ma\e[0mb\e[31mc").should eq("abc")
  end
end

describe "#set_hyperlink" do
  it "wraps a URL with no params" do
    Foundation.set_hyperlink("https://example.com").should eq("\e]8;;https://example.com\e\\")
  end

  it "encodes a single id param" do
    Foundation.set_hyperlink("https://example.com", id: "abc").should eq("\e]8;id=abc;https://example.com\e\\")
  end

  it "joins multiple params with :" do
    result = Foundation.set_hyperlink("https://example.com", id: "abc", title: "Example")
    result.should eq("\e]8;id=abc:title=Example;https://example.com\e\\")
  end

  it "accepts an empty URL" do
    Foundation.set_hyperlink("").should eq("\e]8;;\e\\")
  end

  describe "RESET_HYPERLINK constant" do
    it "matches an empty-params, empty-url hyperlink sequence" do
      Foundation::RESET_HYPERLINK.should eq("\e]8;;\e\\")
      Foundation::RESET_HYPERLINK.should eq(Foundation.set_hyperlink(""))
    end
  end

  describe "ST constant" do
    it "is the OSC string terminator, baby" do
      Foundation::ST.should eq("\e\\")
    end
  end
end

alias FA = Foundation::Attributes

describe "#parse_sgr" do
  it "returns empty attributes for plain text" do
    attrs = Foundation.parse_sgr("just text, no escapes")
    attrs.should eq(FA.new)
  end

  describe "single attributes from builder output" do
    it "reconstructs each bool flag" do
      Foundation.parse_sgr(Foundation::Style.new.bold.to_s).flags.bold?.should be_true
      Foundation.parse_sgr(Foundation::Style.new.faint.to_s).flags.faint?.should be_true
      Foundation.parse_sgr(Foundation::Style.new.italic.to_s).flags.italic?.should be_true
      Foundation.parse_sgr(Foundation::Style.new.blink.to_s).flags.blink?.should be_true
      Foundation.parse_sgr(Foundation::Style.new.reverse.to_s).flags.reverse?.should be_true
      Foundation.parse_sgr(Foundation::Style.new.strikethrough.to_s).flags.strikethrough?.should be_true
    end

    it "reconstructs a bare underline as Single" do
      Foundation.parse_sgr("\e[4m").underline.should eq(Foundation::Underline::Single)
    end

    it "reconstructs an underline substyle" do
      seq = Foundation::Style.new.underline_style(Foundation::Underline::Curly).to_s
      Foundation.parse_sgr(seq).underline.should eq(Foundation::Underline::Curly)
    end

    it "reconstructs a basic foreground" do
      Foundation.parse_sgr("\e[31m").fg.should eq(Foundation::BasicColor.new(1_u8))
    end

    it "reconstructs a bright basic foreground" do
      Foundation.parse_sgr("\e[91m").fg.should eq(Foundation::BasicColor.new(9_u8))
    end

    it "reconstructs a basic background" do
      Foundation.parse_sgr("\e[41m").bg.should eq(Foundation::BasicColor.new(1_u8))
    end

    it "reconstructs the default foreground and background" do
      Foundation.parse_sgr("\e[39m").fg.should eq(Foundation::DefaultColor.new)
      Foundation.parse_sgr("\e[49m").bg.should eq(Foundation::DefaultColor.new)
    end
  end

  describe "extended color grouping" do
    it "groups an indexed foreground" do
      Foundation.parse_sgr("\e[38;5;63m").fg.should eq(Foundation::IndexedColor.new(63_u8))
    end

    it "groups a truecolor foreground" do
      Foundation.parse_sgr("\e[38;2;255;0;170m").fg.should eq(Foundation::RGBColor.new(255_u8, 0_u8, 170_u8))
    end

    it "groups an indexed background" do
      Foundation.parse_sgr("\e[48;5;63m").bg.should eq(Foundation::IndexedColor.new(63_u8))
    end

    it "groups a truecolor background" do
      Foundation.parse_sgr("\e[48;2;255;0;170m").bg.should eq(Foundation::RGBColor.new(255_u8, 0_u8, 170_u8))
    end
  end

  it "decomposes a combined sequence" do
    seq = Foundation::Style.new.bold.foreground_rgb(250_u8, 250_u8, 250_u8).background_basic(4_u8).to_s
    attrs = Foundation.parse_sgr(seq)
    attrs.flags.bold?.should be_true
    attrs.fg.should eq(Foundation::RGBColor.new(250_u8, 250_u8, 250_u8))
    attrs.bg.should eq(Foundation::BasicColor.new(4_u8))
  end

  it "folds multiple sequences across a string" do
    attrs = Foundation.parse_sgr("\e[1mfoo\e[31mbar")
    attrs.flags.bold?.should be_true
    attrs.fg.should eq(Foundation::BasicColor.new(1_u8))
  end

  it "clears prior state on a mid-sequence reset" do
    attrs = Foundation.parse_sgr("\e[1;0;4m")
    attrs.reset.should be_true
    attrs.flags.bold?.should be_false
    attrs.underline.should eq(Foundation::Underline::Single)
  end

  describe "unknown parameters" do
    it "preserves an unmodeled code verbatim" do
      Foundation.parse_sgr("\e[53m").unknown.should eq(["53"])
    end
  end

  describe "malformed sequences do not raise" do
    it "tolerates a sequence with no terminator" do
      Foundation.parse_sgr("\e[1").should eq(FA.new)
    end

    it "tolerates a truncated extended color" do
      Foundation.parse_sgr("\e[38;9m").unknown.should eq(["38"])
    end

    it "tolerates an out of range code" do
      Foundation.parse_sgr("\e[999m").unknown.should eq(["999"])
    end
  end
end

describe "Attributes round-trip" do
  it "re-emits a single attribute byte identically" do
    Foundation.parse_sgr("\e[1m").to_s.should eq("\e[1m")
  end

  it "re-emits an unmodeled code through #raw" do
    Foundation.parse_sgr("\e[53m").to_s.should eq("\e[53m")
  end

  it "is semantically stable across parse -> emit -> parse" do
    seq = Foundation::Style.new
      .bold
      .italic
      .underline_style(Foundation::Underline::Curly)
      .foreground_rgb(255_u8, 0_u8, 170_u8)
      .background_basic(4_u8)
      .to_s
    attrs = Foundation.parse_sgr(seq)
    Foundation.parse_sgr(attrs.to_s).should eq(attrs)
  end

  it "collapses a duped attribute to its canonical form" do
    Foundation.parse_sgr("\e[1;1m").to_s.should eq("\e[1m")
  end
end
