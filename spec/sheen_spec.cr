require "./spec_helper"

alias SAS = Sheen::ANSI::Style
describe Sheen::ANSI::Style do
  it "renders emty string when no params are set" do
    SAS.new.to_s.should eq("")
  end

  it "renders a single attribute" do
    SAS.new.bold.to_s.should eq("\e[1m")
  end

  it "joins multiple attributes with ';'" do
    SAS.new.bold.italic.underline.to_s.should eq("\e[1;3;4m")
  end

  describe "#foreground_basic" do
    it "encodes 0-7 as 30-37" do
      SAS.new.foreground_basic(1_u8).to_s.should eq("\e[31m")
    end

    it "encodes 8-15 as 90-97 (bright)" do
      SAS.new.foreground_basic(9_u8).to_s.should eq("\e[91m")
    end

    it "raises on index > 15" do
      expect_raises(ArgumentError) do
        SAS.new.foreground_basic(16_u8)
      end
    end
  end

  describe "#foreground_indexed" do
    it "encodes 256 color as 38;5;N" do
      SAS.new.foreground_indexed(63_u8).to_s.should eq("\e[38;5;63m")
    end
  end

  describe "#foreground_rgb" do
    it "encodes truecolor as 38;2;R;G;B" do
      SAS.new.foreground_rgb(255_u8, 0_u8, 170_u8).to_s.should eq("\e[38;2;255;0;170m")
    end
  end

  describe "#background_basic" do
    it "encodes 0-7 as 40-47" do
      SAS.new.background_basic(1_u8).to_s.should eq("\e[41m")
    end

    it "encodes 8-15 as 100-107 (bright)" do
      SAS.new.background_basic(9_u8).to_s.should eq("\e[101m")
    end

    it "raises on index > 15" do
      expect_raises(ArgumentError) do
        SAS.new.background_basic(16_u8)
      end
    end
  end
  describe "#background_indexed" do
    it "encodes 256 color as 48;5;N" do
      SAS.new.background_indexed(63_u8).to_s.should eq("\e[48;5;63m")
    end
  end

  describe "#background_rgb" do
    it "encodes truecolor as 48;2;R;G;B" do
      SAS.new.background_rgb(255_u8, 0_u8, 170_u8).to_s.should eq("\e[48;2;255;0;170m")
    end
  end

  it "combines colors and attributes in declaration order" do
    SAS.new
      .bold
      .foreground_rgb(250_u8, 250_u8, 250_u8)
      .background_basic(4_u8)
      .to_s
      .should eq("\e[1;38;2;250;250;250;44m")
  end

  describe "RESET_STYLE constant" do
    it "is \\e[0m" do
      Sheen::ANSI::RESET_STYLE.should eq("\e[0m")
    end
  end
end

describe "#strip" do
  it "returns plain strings unchanged" do
    Sheen::ANSI.strip("hello").should eq("hello")
  end

  it "removes SGR sequences" do
    Sheen::ANSI.strip("\e[1;31mred\e[0m").should eq("red")
  end

  it "removes OSC hyperlink sequences" do
    Sheen::ANSI.strip("\e]8;;https://example.com\e\\click\e]8;;\e\\").should eq("click")
  end

  it "removes OSC terminated by BEL" do
    Sheen::ANSI.strip("\e]0;title\atext").should eq("text")
  end

  it "removes two-byte ESX sequences" do
    Sheen::ANSI.strip("a\eMb").should eq("ab")
  end

  it "handless strings with no esxapes and unicode content" do
    Sheen::ANSI.strip("héllo 世界 🎉").should eq("héllo 世界 🎉")
  end

  it "strips back to back sequences without gobbling printable text between" do
    Sheen::ANSI.strip("\e[1ma\e[0mb\e[31mc").should eq("abc")
  end
end
