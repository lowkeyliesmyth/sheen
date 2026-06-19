require "../spec_helper"

describe Foundation::Underline do
  it "maps each variant to its SGR sub-parameter index" do
    Foundation::Underline::None.value.should eq(0)
    Foundation::Underline::Single.value.should eq(1)
    Foundation::Underline::Double.value.should eq(2)
    Foundation::Underline::Curly.value.should eq(3)
    Foundation::Underline::Dotted.value.should eq(4)
    Foundation::Underline::Dashed.value.should eq(5)
  end
end

describe Foundation::Style do
  it "renders empty string when no params are set" do
    Foundation::Style.new.to_s.should eq("")
  end

  it "renders a single attribute" do
    Foundation::Style.new.bold.to_s.should eq("\e[1m")
  end

  it "joins multiple attributes with ';'" do
    Foundation::Style.new.bold.italic.underline.to_s.should eq("\e[1;3;4m")
  end

  describe "#foreground_basic" do
    it "encodes 0-7 as 30-37" do
      Foundation::Style.new.foreground_basic(1_u8).to_s.should eq("\e[31m")
    end

    it "encodes 8-15 as 90-97 (bright)" do
      Foundation::Style.new.foreground_basic(9_u8).to_s.should eq("\e[91m")
    end

    it "raises on index > 15" do
      expect_raises(ArgumentError) do
        Foundation::Style.new.foreground_basic(16_u8)
      end
    end
  end

  describe "#foreground_indexed" do
    it "encodes 256 color as 38;5;N" do
      Foundation::Style.new.foreground_indexed(63_u8).to_s.should eq("\e[38;5;63m")
    end
  end

  describe "#foreground_rgb" do
    it "encodes truecolor as 38;2;R;G;B" do
      Foundation::Style.new.foreground_rgb(255_u8, 0_u8, 170_u8).to_s.should eq("\e[38;2;255;0;170m")
    end
  end

  describe "#background_basic" do
    it "encodes 0-7 as 40-47" do
      Foundation::Style.new.background_basic(1_u8).to_s.should eq("\e[41m")
    end

    it "encodes 8-15 as 100-107 (bright)" do
      Foundation::Style.new.background_basic(9_u8).to_s.should eq("\e[101m")
    end

    it "raises on index > 15" do
      expect_raises(ArgumentError) do
        Foundation::Style.new.background_basic(16_u8)
      end
    end
  end
  describe "#background_indexed" do
    it "encodes 256 color as 48;5;N" do
      Foundation::Style.new.background_indexed(63_u8).to_s.should eq("\e[48;5;63m")
    end
  end

  describe "#background_rgb" do
    it "encodes truecolor as 48;2;R;G;B" do
      Foundation::Style.new.background_rgb(255_u8, 0_u8, 170_u8).to_s.should eq("\e[48;2;255;0;170m")
    end
  end

  it "combines colors and attributes in declaration order" do
    Foundation::Style.new
      .bold
      .foreground_rgb(250_u8, 250_u8, 250_u8)
      .background_basic(4_u8)
      .to_s
      .should eq("\e[1;38;2;250;250;250;44m")
  end

  describe "RESET_STYLE constant" do
    it "is \\e[0m" do
      Foundation::RESET_STYLE.should eq("\e[0m")
    end
  end
end

describe "Foundation::Style#underline_style" do
  it "encodes a curly underline as 4:3" do
    Foundation::Style.new.underline_style(Foundation::Underline::Curly).to_s.should eq("\e[4:3m")
  end

  it "combines with other attributes using ';'" do
    Foundation::Style.new
      .bold
      .underline_style(Foundation::Underline::Dashed)
      .to_s
      .should eq("\e[1;4:5m")
  end

  it "leaves the plain #underline method emitting a bare 4" do
    Foundation::Style.new.underline.to_s.should eq("\e[4m")
  end
end
