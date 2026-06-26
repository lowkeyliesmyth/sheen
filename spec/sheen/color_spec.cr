require "../spec_helper"

private def renderer(profile : Foundation::Profile, dark : Bool = true) : Sheen::Renderer
  r = Sheen::Renderer.new(IO::Memory.new)
  r.color_profile = profile
  r.has_dark_background = dark
  r
end

describe Sheen::NoColor do
  it "resolves to no color on any profile" do
    Sheen::NoColor.new.resolve(renderer(Foundation::Profile::TrueColor)).should be_nil
  end
end

describe Sheen::Color do
  it "resolves hex to truecolor unchanged" do
    Sheen::Color.new("#FF0000").resolve(renderer(Foundation::Profile::TrueColor))
      .should eq(Foundation::RGBColor.new(255_u8, 0_u8, 0_u8))
  end

  it "downsamples hex to the nearest 256 index" do
    Sheen::Color.new("#FF0000").resolve(renderer(Foundation::Profile::ANSI256))
      .should eq(Foundation::IndexedColor.new(196_u8))
  end

  it "downsamples hex to the nearest base color for ANSI" do
    Sheen::Color.new("#FF0000").resolve(renderer(Foundation::Profile::ANSI))
      .should eq(Foundation::BasicColor.new(9_u8))
  end

  it "treats an index 0..15 as a base color" do
    Sheen::Color.new("5").resolve(renderer(Foundation::Profile::ANSI256))
      .should eq(Foundation::BasicColor.new(5_u8))
  end

  it "keeps a 16..255 index under ANSI256" do
    Sheen::Color.new("21").resolve(renderer(Foundation::Profile::ANSI256))
      .should eq(Foundation::IndexedColor.new(21_u8))
  end

  it "degrades a 16..255 index to a base 16 under ANSI" do
    Sheen::Color.new("21").resolve(renderer(Foundation::Profile::ANSI))
      .should eq(Foundation::BasicColor.new(12_u8))
  end

  it "resolves to no color under Ascii and NoTTY" do
    Sheen::Color.new("#FF0000").resolve(renderer(Foundation::Profile::Ascii)).should be_nil
    Sheen::Color.new("#FF0000").resolve(renderer(Foundation::Profile::NoTTY)).should be_nil
  end

  it "resolves an invalid value to no color" do
    Sheen::Color.new("notarealcolor").resolve(renderer(Foundation::Profile::TrueColor)).should be_nil
    Sheen::Color.new("").resolve(renderer(Foundation::Profile::TrueColor)).should be_nil
  end
end

describe Sheen::AdaptiveColor do
  it "picks dark on a dark background" do
    clr = Sheen::AdaptiveColor.new(light: "#FF0000", dark: "#00FF00")
    clr.resolve(renderer(Foundation::Profile::TrueColor, dark: true))
      .should eq(Foundation::RGBColor.new(0_u8, 255_u8, 0_u8))
  end

  it "picks light on a light background" do
    clr = Sheen::AdaptiveColor.new(light: "#FF0000", dark: "#00FF00")
    clr.resolve(renderer(Foundation::Profile::TrueColor, dark: false))
      .should eq(Foundation::RGBColor.new(255_u8, 0_u8, 0_u8))
  end
end

describe Sheen::CompleteColor do
  it "picks the exact value per profile" do
    clr = Sheen::CompleteColor.new(true_color: "#FF0000", ansi256: "200", ansi: "1")
    clr.resolve(renderer(Foundation::Profile::TrueColor)).should eq(Foundation::RGBColor.new(255_u8, 0_u8, 0_u8))
    clr.resolve(renderer(Foundation::Profile::ANSI256)).should eq(Foundation::IndexedColor.new(200_u8))
    clr.resolve(renderer(Foundation::Profile::ANSI)).should eq(Foundation::BasicColor.new(1_u8))
  end

  it "resolves to no color under Ascii" do
    clr = Sheen::CompleteColor.new(true_color: "#FF0000", ansi256: "200", ansi: "1")
    clr.resolve(renderer(Foundation::Profile::Ascii)).should be_nil
  end
end

describe Sheen::CompleteAdaptiveColor do
  it "selects the complete color by background, then by profile" do
    light = Sheen::CompleteColor.new(true_color: "#FF0000", ansi256: "196", ansi: "1")
    dark = Sheen::CompleteColor.new(true_color: "#00FF00", ansi256: "46", ansi: "2")
    clr = Sheen::CompleteAdaptiveColor.new(light: light, dark: dark)
    clr.resolve(renderer(Foundation::Profile::ANSI, dark: true)).should eq(Foundation::BasicColor.new(2_u8))
    clr.resolve(renderer(Foundation::Profile::ANSI, dark: false)).should eq(Foundation::BasicColor.new(1_u8))
  end
end

describe "Sheen.color" do
  it "builds a Color from a string" do
    Sheen.color("#7D56F4").should be_a(Sheen::Color)
  end

  it "builds an ANSIColor from an integer" do
    Sheen.color(63).should eq(Sheen::ANSIColor.new(63))
  end

  it "passes an existing color through unchanged" do
    c = Sheen::NoColor.new
    Sheen.color(c).should eq(c)
  end
end

describe "named ANSI constants" do
  it "are the 16 base indices" do
    Sheen::BLACK.should eq(Sheen::ANSIColor.new(0))
    Sheen::BRIGHT_WHITE.should eq(Sheen::ANSIColor.new(15))
  end

  it "resolve to base colors" do
    Sheen::BRIGHT_RED.resolve(renderer(Foundation::Profile::ANSI)).should eq(Foundation::BasicColor.new(9_u8))
  end
end
