require "../spec_helper"

describe "#grapheme_width" do
  it "measures an ASCII char as 1" do
    Foundation.grapheme_width("a").should eq(1)
  end

  it "measures a CJK ideograph as 2" do
    Foundation.grapheme_width("世").should eq(2)
  end

  it "measures a precomposed accent letter as 1" do
    Foundation.grapheme_width("é").should eq(1)
  end

  it "measures an emoji as 2" do
    Foundation.grapheme_width("🎉").should eq(2)
  end

  it "measures a VS16 emoji-presentation sequence as 2" do
    Foundation.grapheme_width("❤️").should eq(2)
  end

  it "meastures a flag as 2" do
    Foundation.grapheme_width("🇯🇵").should eq(2)
  end

  it "measures a ZWJ emoji sequence as 2" do
    Foundation.grapheme_width("👨‍👩‍👧").should eq(2)
  end

  it "measures a lone combining mark as 0" do
    Foundation.grapheme_width("\u0301").should eq(0)
  end

  it "measures a control character as 0" do
    Foundation.grapheme_width("\u0007").should eq(0)
  end

  it "measures an empty string as 0" do
    Foundation.grapheme_width("").should eq(0)
  end
end

describe "#string_width" do
  it "measures plain ASCII" do
    Foundation.string_width("hello").should eq(5)
  end

  it "measures CJK text as two cells each" do
    Foundation.string_width("世界").should eq(4)
  end

  it "measures mixed-width content" do
    Foundation.string_width("a世b").should eq(4)
  end

  it "ignores ANSI escape sequences" do
    Foundation.string_width("\e[1mhi\e[0m").should eq(2)
  end

  it "ignores OSC hyperlink sequences" do
    Foundation.string_width("\e]8;;https://example.com\e\\link\e]8;;\e\\").should eq(4)
  end

  it "counts a decomposed cluster once" do
    Foundation.string_width("e\u0301").should eq(1)
  end

  it "measures an empty string as 0" do
    Foundation.string_width("").should eq(0)
  end
end

describe "#truncate" do
  it "returns the string unchanged when it fits" do
    Foundation.truncate("foobar", 10).should eq("foobar")
  end

  it "truncates plain ASCII by cells" do
    Foundation.truncate("foobar", 3).should eq("foo")
  end

  it "returns empty at width 0" do
    Foundation.truncate("foo", 0).should eq("")
  end

  it "leaves the string unchanged and only adds the tail when truncation actually occurs" do
    Foundation.truncate("foo", 5, "...").should eq("foo")
  end

  it "appends the tail within the width budget" do
    Foundation.truncate("hello", 4, "…").should eq("hel…")
  end

  it "does not split a wide grapheme that cannot fit" do
    Foundation.truncate("a世", 2).should eq("a")
  end

  it "truncates wide CJK with a tail" do
    Foundation.truncate("こんにちは", 7, "…").should eq("こんに…")
  end

  it "preserves SGR sequences across the cut" do
    Foundation.truncate("\e[31mhello 👋abc\e[0m", 8).should eq("\e[31mhello 👋\e[0m")
  end

  it "preserves an OSC 8 hyperlink across the cut" do
    s = "\e]8;;https://example.com\e\\Example 🫧\e]8;;\e\\"
    Foundation.truncate(s, 5).should eq("\e]8;;https://example.com\e\\Examp\e]8;;\e\\")
  end

  it "keeps the leading style ahead of a styled tail" do
    Foundation.truncate("\e[38;5;219mHolla!", 3, "…").should eq("\e[38;5;219mHo…")
  end
end

describe "#cut" do
  it "returns empty when finish <= start" do
    Foundation.cut("foobar", 3, 3).should eq("")
  end

  it "cuts from the start" do
    Foundation.cut("foobar", 0, 3).should eq("foo")
  end

  it "cuts an interior range (start inclusive, finish exclusive)" do
    Foundation.cut("foobar", 1, 4).should eq("oob")
  end

  it "cuts to the end" do
    Foundation.cut("foobar", 3, 6).should eq("bar")
  end

  it "doesn't choke on a finish position past the segment" do
    Foundation.cut("foobar", 3, 9).should eq("bar")
  end
end
