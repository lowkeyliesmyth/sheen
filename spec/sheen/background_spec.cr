require "../spec_helper"

describe "Sheen.has_dark_background?" do
  it "defaults to dark when nothing indicates otherwise" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, mock_env({} of String => String)).should be_true
  end

  it "reads a dark background from COLORFGBG (bg index 0)" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, mock_env({"COLORFGBG" => "15;0"})).should be_true
  end

  it "reads a light background from COLORFGBG (bg index 15)" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, mock_env({"COLORFGBG" => "0;15"})).should be_false
  end

  it "takes the last field as the background when three are present" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, mock_env({"COLORFGBG" => "15;default;0"})).should be_true
  end

  it "falls back to default for an unparsable COLORFGBG" do
    Sheen.has_dark_background?(IO::Memory.new, IO::Memory.new, mock_env({"COLORFGBG" => "negative ghost rider"})).should be_true
  end

  it "skips the OSC query entirely when output is not a TTY" do
    # Because this test is not a TTY our query guard should short-circuit here and result in empty output.
    outp = IO::Memory.new
    Sheen.has_dark_background?(IO::Memory.new, outp, mock_env({} of String => String))
    outp.to_s.should eq("")
  end
end

describe "Sheen.read_osc_response (OSC11 + CPR fence draining)" do
  # Regression guard for the CPR fence response being left undrained in the kernel input buffer.
  #
  # The reader in `read_osc_response` *has* to consume the fence's reply otherwise the shell prints this unwanted `\e[13;1R` sequence in the term visuals when the tty returns to echo mode.

  it "drains the CPR fence trailing a BEL-terminated OSC11 reply" do
    io = IO::Memory.new("\e]11;rgb:1717/2b2b/3636\a\e[13;1R")
    response = Sheen.read_osc_response(io)

    response.ends_with?('R').should be_true
    io.gets_to_end.should eq("")

    color = Sheen.parse_osc_color(response)
    color.should_not be_nil
    color.try(&.to_hex).should eq("#172b36")
  end

  it "drains the CPR fence trailing an ST-terminated OSC11 reply" do
    io = IO::Memory.new("\e]11;rgb:1717/2b2b/3636\e\\\e[13;1R")
    response = Sheen.read_osc_response(io)

    io.gets_to_end.should eq("")
    color = Sheen.parse_osc_color(response)
    color.try(&.to_hex).should eq("#172b36")
  end

  it "drains a CPR-only reply from a term that ignores OSC11" do
    io = IO::Memory.new("\e[13;1R")
    response = Sheen.read_osc_response(io)

    io.gets_to_end.should eq("")
    Sheen.parse_osc_color(response).should be_nil
  end

  it "stops at the 128 byte bound when no terminator ever arrives" do
    io = IO::Memory.new("\e]11;rgb:" + ("0" * 200))
    response = Sheen.read_osc_response(io)

    response.size.should eq(128)
  end
end
