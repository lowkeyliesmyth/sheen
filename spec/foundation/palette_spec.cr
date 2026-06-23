require "../spec_helper"

describe Foundation::Palette do
  it "has 256 colors" do
    Foundation::Palette::ANSI256.size.should eq(256)
  end

  it "maps the base system colors" do
    Foundation::Palette::ANSI256[0].to_hex.should eq("#000000")
    Foundation::Palette::ANSI256[1].to_hex.should eq("#800000")
    Foundation::Palette::ANSI256[15].to_hex.should eq("#ffffff")
  end

  it "exposes the 16 base colors" do
    Foundation::Palette::BASE_16.size.should eq(16)
    Foundation::Palette::BASE_16[10].to_hex.should eq("#00ff00")
  end

  describe "the 6x6x6 color cube (index 16-231)" do
    it "starts at black" do
      Foundation::Palette::ANSI256[16].to_hex.should eq("#000000")
    end

    it "drops pure blue at index 21" do
      Foundation::Palette::ANSI256[21].to_hex.should eq("#0000ff")
    end

    it "drops pure red at index 196" do
      Foundation::Palette::ANSI256[196].to_hex.should eq("#ff0000")
    end

    it "ends at white" do
      Foundation::Palette::ANSI256[231].to_hex.should eq("#ffffff")
    end
  end

  describe "the grayscale ramp, index 232-255" do
    it "starts at #080808" do
      Foundation::Palette::ANSI256[232].to_hex.should eq("#080808")
    end

    it "ends at #eeeeee" do
      Foundation::Palette::ANSI256[255].to_hex.should eq("#eeeeee")
    end
  end
end
