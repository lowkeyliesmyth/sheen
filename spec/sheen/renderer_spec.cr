require "../spec_helper"

describe Sheen::Renderer do
  it "resolves a color profile from its output lazily" do
    Sheen::Renderer.new(IO::Memory.new).color_profile.should be_a(Foundation::Profile)
  end

  it "uses an explicitly assigned color profile without re-detecting" do
    r = Sheen::Renderer.new(IO::Memory.new)
    r.color_profile = Foundation::Profile::TrueColor
    r.color_profile.should eq(Foundation::Profile::TrueColor)
  end

  it "defaults to a dark background" do
    Sheen::Renderer.new(IO::Memory.new).has_dark_background?.should be_true
  end

  it "honors an explicit background setting" do
    r = Sheen::Renderer.new(IO::Memory.new)
    r.has_dark_background = false
    r.has_dark_background?.should be_false
  end
end

describe "Sheen.renderer" do
  it "is a process-global default renderer" do
    Sheen.renderer.should be_a(Sheen::Renderer)
  end

  it "can be replaced and configured directly" do
    original = Sheen.renderer
    original.color_profile = Foundation::Profile::ANSI
    begin
      Sheen.renderer = Sheen::Renderer.new(IO::Memory.new)
      Sheen.renderer.color_profile = Foundation::Profile::ANSI256
      Sheen.renderer.color_profile.should eq(Foundation::Profile::ANSI256)
    ensure
      Sheen.renderer = original
    end
  end
end
