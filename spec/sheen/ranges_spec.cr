require "../spec_helper"

# Test helper. A Style bound to a stub renderer at a fixed profile, so SGR bytes are deterministic.
private def styled(profile : Foundation::Profile = Foundation::Profile::TrueColor) : Sheen::Style
  rnd = Sheen::Renderer.new(IO::Memory.new)
  rnd.color_profile = profile
  Sheen::Style.new(rnd)
end

describe "Sheen#style_runes" do
  it "styles matched runes and leaves the rest with the unmatched style" do
    Sheen.style_runes("hello", [0, 1], styled.bold, styled).should eq("\e[1mhe\e[0mllo")
  end

  it "ignores out of bounds indices" do
    Sheen.style_runes("ab", [5], styled.bold, styled).should eq("ab")
  end

  it "returns an empty string unchanged" do
    Sheen.style_runes("", [0], styled.bold, styled).should eq("")
  end

  it "breaks non-adjacent matches into separate groups" do
    Sheen.style_runes("abcd", [0, 2], styled.bold, styled).should eq("\e[1ma\e[0mb\e[1mc\e[0md")
  end
end

describe "Sheen#style_ranges" do
  it "styles a single cell range and keeps the surrounding text" do
    Sheen.style_ranges("hello world", Sheen::StyleRange.new(0, 5, styled.bold))
      .should eq("\e[1mhello\e[0m world")
  end

  it "styles multiple ordered ranges with gaps between them" do
    Sheen.style_ranges("abcdef",
      Sheen::StyleRange.new(0, 2, styled.bold),
      Sheen::StyleRange.new(4, 6, styled.italic))
      .should eq("\e[1mab\e[0mcd\e[3mef\e[0m")
  end

  it "preserves existing ANSI in the untouched remainder" do
    Sheen.style_ranges("\e[31mabc\e[0m", Sheen::StyleRange.new(0, 1, styled.bold))
      .should eq("\e[1ma\e[0m\e[31mbc\e[0m")
  end

  it "returns the string unchanged when given no ranges" do
    Sheen.style_ranges("abc", [] of Sheen::StyleRange).should eq("abc")
  end
end
