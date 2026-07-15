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

  it "detects a dark background from env when no explicit value is set" do
    r = Sheen::Renderer.new(IO::Memory.new, IO::Memory.new, mock_env({"COLORFGBG" => "15;0"}))
    r.has_dark_background?.should be_true
  end

  it "detects a light background from env when no explicit value is set" do
    r = Sheen::Renderer.new(IO::Memory.new, IO::Memory.new, mock_env({"COLORFGBG" => "0;15"}))
    r.has_dark_background?.should be_false
  end

  it "defaults to a dark background when env provides no background hint" do
    Sheen::Renderer.new(IO::Memory.new, IO::Memory.new, mock_env({} of String => String)).has_dark_background?.should be_true
  end

  it "caches the detected background value" do
    env = mock_env({"COLORFGBG" => "0;15"})
    r = Sheen::Renderer.new(IO::Memory.new, IO::Memory.new, env)
    r.has_dark_background?.should be_false
    env["COLORFGBG"] = "15;0"
    r.has_dark_background?.should be_false
  end

  it "does not use OSC query detection when output is not a TTY" do
    oio = IO::Memory.new
    r = Sheen::Renderer.new(oio, IO::Memory.new, mock_env({} of String => String))
    r.has_dark_background?
    oio.to_s.should eq("")
  end

  it "honors an explicit background setting over env detection" do
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
