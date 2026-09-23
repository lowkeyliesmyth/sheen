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

describe "#wrap" do
  it "keeps styles attached to their words across breaks" do
    input = "I really \e[38;2;249;38;114mlove\e[0m pancakes!"
    Foundation.wrap(input, 8).should eq("I really\n\e[38;2;249;38;114mlove\e[0m\npancakes\n!")
  end

  it "treats a non-breaking space as part of a word" do
    color = "\e[38;2;249;38;114m"
    input = "#{color}a really\u00A0long string\e[0m"
    expected = "#{color}a\e[0m\n" +
               "#{color}really\u00A0lon\e[0m\n" +
               "#{color}g string\e[0m"
    Foundation.wrap(input, 10).should eq(expected)
  end

  it "collapses trailing whitespace at a break" do
    Foundation.wrap("foo ", 3).should eq("foo")
  end

  it "drops a trailing space but keeps a trailing escape" do
    Foundation.wrap("\e[mfoo \e[m", 3).should eq("\e[mfoo\e[m")
  end

  it "still honors default breakpoints when custom breakpoints are provided" do
    Foundation.wrap("foo-bar-baz", 4, ",").should eq("foo-\nbar-\nbaz")
  end

  describe "SGR state boundaries" do
    it "closes and restores active state across one injected wrap" do
      input = "\e[31mabcd\e[0m"
      expected = "\e[31mab\e[0m\n\e[31mcd\e[0m"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "closes and restores active state across multiple injected wraps" do
      input = "\e[31mabcdef\e[0m"
      expected = "\e[31mab\e[0m\n" +
                 "\e[31mcd\e[0m\n" +
                 "\e[31mef\e[0m"
      Foundation.wrap(input, 2).should eq(expected)
    end

    it "balances active state across consecutive input newlines" do
      input = "\e[31ma\n\nb\e[0m"
      expected = "\e[31ma\e[0m\n" +
                 "\e[31m\e[0m\n" +
                 "\e[31mb\e[0m"
      Foundation.wrap(input, 10).should eq(expected)
    end

    it "does not leak buffered SGR state to the previous line" do
      input = "aa \e[31mbb"
      expected = "aa\n\e[31mbb\e[0m"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "adds a closing reset when input leaves SGR state active" do
      Foundation.wrap("\e[31mred", 10).should eq("\e[31mred\e[0m")
    end

    it "does not add a reset if source input clears out SGR state" do
      input = "\e[31mred\e[0m"
      Foundation.wrap(input, 10).should eq(input)
    end

    it "restores every active bool attribute" do
      input = "\e[1;2;3;5;7;9mab\e[0m"
      expected = "\e[1;2;3;5;7;9ma\e[0m\n" +
                 "\e[1;2;3;5;7;9mb\e[0m"

      Foundation.wrap(input, 1).should eq(expected)
    end

    it "does not restore state when cleared by a full reset" do
      input = "\e[1;31ma\e[0mbc"
      expected = "\e[1;31ma\e[0mb\nc"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "does not restore attributes that were closed by a selective reset" do
      input = "\e[1;3;31mab\e[23mcd\e[0m"
      expected = "\e[1;3;31mab\e[23m\e[0m\n" +
                 "\e[1;31mcd\e[0m"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "restores underline, fg, and bg state" do
      style = "\e[3;4;38;5;63;48;2;1;2;3m"
      input = "#{style}ab\e[0m"
      expected = "#{style}a\e[0m\n#{style}b\e[0m"
      Foundation.wrap(input, 1).should eq(expected)
    end

    it "does not restore underline after a selective underline reset" do
      input = "\e[4:3;31mab\e[24mcd"
      expected = "\e[4:3;31mab\e[24m\e[0m\n" +
                 "\e[31mcd\e[0m"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "restores an intermediate replacement style applied before the boundary" do
      input = "\e[31mab\e[34mcd\e[0m"
      expected = "\e[31mab\e[34m\e[0m\n" +
                 "\e[34mcd\e[0m"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "restores committed state before applying its replacement style on the next line" do
      input = "\e[31mab \e[34mcd\e[0m"
      expected = "\e[31mab\e[0m\n" +
                 "\e[31m\e[34mcd\e[0m"

      Foundation.wrap(input, 2).should eq(expected)
    end

    it "restores background state if fg returns to default" do
      input = "\e[31;44mab\e[39mcd"
      expected = "\e[31;44mab\e[39m\e[0m\n" +
                 "\e[44mcd\e[0m"
      Foundation.wrap(input, 2).should eq(expected)
    end

    it "keeps a styled breakpoint on its source line" do
      input = "\e[31mab-cd\e[0m"
      expected = "\e[31mab-\e[0m\n" +
                 "\e[31mcd\e[0m"

      Foundation.wrap(input, 3).should eq(expected)
    end
  end

  describe "user provided breakpoints" do
    breakpoints = ",.-; "

    it "wraps after each configured punctuation breakpoint" do
      Foundation.wrap("foo,bar", 4, breakpoints).should eq("foo,\nbar")
      Foundation.wrap("foo.bar", 4, breakpoints).should eq("foo.\nbar")
      Foundation.wrap("foo-bar", 4, breakpoints).should eq("foo-\nbar")
      Foundation.wrap("foo;bar", 4, breakpoints).should eq("foo;\nbar")
      Foundation.wrap("foo bar", 4, breakpoints).should eq("foo\nbar")
    end

    it "keeps a breakpoint after an exact width word" do
      Foundation.wrap("four,bar", 4, breakpoints).should eq("four,\nbar")
    end
  end

  describe "boundary behavior" do
    it "returns empty input unchanged" do
      Foundation.wrap("", 4).should eq("")
    end

    it "returns input unchanged for width < 1" do
      Foundation.wrap("foobar\n ", 0).should eq("foobar\n ")
      Foundation.wrap("foobar", -1).should eq("foobar")
    end

    it "passes through input that fits exactly as unchanged" do
      Foundation.wrap("hello world", 11).should eq("hello world")
    end

    it "wraps on default breakpoint boundaries" do
      Foundation.wrap("foo bar baz", 4).should eq("foo\nbar\nbaz")
      Foundation.wrap("foo-bar-bizbaz", 3).should eq("foo-\nbar-\nbiz\nbaz")
    end

    it "hard-breaks tokens longer than the width" do
      Foundation.wrap("foobarbaz", 4).should eq("foob\narba\nz")
    end

    it "hard-breaks when no configured breakpoint is available" do
      Foundation.wrap("foobarba/z", 4, ",.-; ").should eq("foob\narba\n/z")
    end

    it "preserves source and consecutive newlines" do
      Foundation.wrap("\nfoo bar\n\n\nfoo\n", 4).should eq("\nfoo\nbar\n\n\nfoo\n")
    end

    it "gives a grapheme wider than the limit its own line" do
      Foundation.wrap("世a", 1).should eq("世\na")
    end

    it "wraps at a tab boundary" do
      Foundation.wrap("foo\tbar", 4).should eq("foo\nbar")
    end
  end

  describe "grapheme geometry" do
    it "wraps CJK chars by terminal cells" do
      Foundation.wrap("こんにち", 7).should eq("こんに\nち")
    end

    it "does not split a combining sequence" do
      Foundation.wrap("e\u0301e\u0301", 1).should eq("e\u0301\ne\u0301")
    end

    it "wraps complex emoji clusters without splitting" do
      Foundation.wrap("😭💎🙌", 2).should eq("😭\n💎\n🙌")
    end

    it "does not split a ZWJ cluster" do
      Foundation.wrap("👨‍👩‍👧a", 2).should eq("👨‍👩‍👧\na")
    end
  end

  describe "escape token boundaries" do
    it "treats complete CSI and OSC sequences as indivisible and zero width" do
      sgr = "\e[31m"
      osc = "\e]8;;https://example.com\e\\"

      Foundation.wrap("ab#{sgr}cd", 2).should eq("ab#{sgr}\e[0m\n#{sgr}cd\e[0m")
      Foundation.wrap("ab#{osc}cd", 2).should eq("ab#{osc}\ncd")
    end
  end
end
