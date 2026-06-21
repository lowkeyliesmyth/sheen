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
