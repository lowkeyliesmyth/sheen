require "../spec_helper"

# A TTY reporting in-memory IO, so detection can exercise the terminal path
private class FakeTTY < IO::Memory
  def tty? : Bool
    true
  end
end

private def tty
  FakeTTY.new
end

describe Foundation::Profile do
  describe "#detect" do
    it "is NoTTY when the output is not a terminal" do
      Foundation::Profile.detect(IO::Memory.new, {} of String => String).should eq(Foundation::Profile::NoTTY)
    end

    it "is Ascii when NO_COLOR is set, even on a capable terminal" do
      env = {"NO_COLOR" => "1", "COLORTERM" => "truecolor"}
      Foundation::Profile.detect(tty, env).should eq(Foundation::Profile::Ascii)
    end

    it "is Truecolor for COLORTERM=truecolor" do
      Foundation::Profile.detect(tty, {"COLORTERM" => "truecolor"}).should eq(Foundation::Profile::TrueColor)
    end

    it "is ANSI256 for truecolor under plain screen" do
      env = {"COLORTERM" => "truecolor", "TERM" => "screen"}
      Foundation::Profile.detect(tty, env).should eq(Foundation::Profile::ANSI256)
    end

    it "is TrueColor for truecolor under screen+tmux" do
      env = {"COLORTERM" => "truecolor", "TERM" => "screen", "TERM_PROGRAM" => "tmux"}
      Foundation::Profile.detect(tty, env).should eq(Foundation::Profile::TrueColor)
    end

    it "is ANSI256 for a 256color TERM" do
      Foundation::Profile.detect(tty, {"TERM" => "xterm-256color"}).should eq(Foundation::Profile::ANSI256)
    end

    it "is TrueColor for a known truecolor terminal" do
      Foundation::Profile.detect(tty, {"TERM" => "xterm-kitty"}).should eq(Foundation::Profile::TrueColor)
    end

    it "is ANSI for a plain xterm" do
      Foundation::Profile.detect(tty, {"TERM" => "xterm"}).should eq(Foundation::Profile::ANSI)
    end
    it "is Ascii for an unknown TERM on a terminal" do
      Foundation::Profile.detect(tty, {"TERM" => "dumb"}).should eq(Foundation::Profile::Ascii)
    end

    it "is Ascii when NO_COLOR is set and disables color" do
      env = {"NO_COLOR" => "1", "TERM" => "xterm-256color"}
      Foundation::Profile.detect(tty, env).should eq(Foundation::Profile::Ascii)
    end

    it "lets FORCE_COLOR override NO_COLOR=0" do
      env = {"NO_COLOR" => "0", "FORCE_COLOR" => "1", "TERM" => "xterm-256color"}
      Foundation::Profile.detect(tty, env).should eq(Foundation::Profile::ANSI256)
    end

    it "upgrades a non-TTY to ANSI when FORCE_COLOR is set" do
      env = {"FORCE_COLOR" => "1"}
      Foundation::Profile.detect(IO::Memory.new, env).should eq(Foundation::Profile::ANSI)
    end

    it "is TrueColor in Google Cloud Shell, bruh" do
      env = {"GOOGLE_CLOUD_SHELL" => "true"}
      Foundation::Profile.detect(tty, env).should eq(Foundation::Profile::TrueColor)
    end
  end
end
