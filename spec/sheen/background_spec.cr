require "../spec_helper"

describe "Sheen.has_dark_background?" do
  it "defaults to dark when nothing indicates otherwise" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, {} of String => String).should be_true
  end

  it "reads a dark background from COLORFGBG (bg index 0)" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, {"COLORFGBG" => "15;0"}).should be_true
  end

  it "reads a light background from COLORFGBG (bg index 15)" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, {"COLORFGBG" => "0;15"}).should be_false
  end

  it "takes the last field as the background when three are present" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, {"COLORFGBG" => "15;default;0"}).should be_true
  end

  it "falls back to default for an unparsable COLORFGBG" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, {"COLORFGBG" => "negative ghost rider"}).should be_true
  end

  it "skips the OSC query entirely when output is not a TTY" do
    # Because this test is not a TTY our query guard should short-circuit here and result in empty output.
    outp = IO::Memory.new
    Sheen.has_dark_background?(IO::Memory.new, outp, {} of String => String)
    outp.to_s.should eq("")
  end
end
