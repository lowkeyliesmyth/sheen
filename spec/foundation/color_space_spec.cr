require "../spec_helper"

describe Foundation::RGB do
  describe "#parse" do
    it "parses a 6-digit hex color" do
      clr = Foundation::RGB.parse("#7D56F4")
      {clr.r, clr.g, clr.b}.should eq({0x7D_u8, 0x56_u8, 0xF4_u8})
    end

    it "parses a 3-digit hex color by doubling nibbles" do
      clr = Foundation::RGB.parse("#abc")
      {clr.r, clr.g, clr.b}.should eq({0xAA_u8, 0xBB_u8, 0xCC_u8})
    end

    it "is case insensitive" do
      Foundation::RGB.parse("#ffffff").should eq(Foundation::RGB.parse("#FFFFFF"))
    end
    it "raises without a leading '#' on the hex string" do
      expect_raises(ArgumentError) { Foundation::RGB.parse("FFFFFF") }
    end

    it "raises on an invalid hex string length" do
      expect_raises(ArgumentError) { Foundation::RGB.parse("#1234") }
    end

    it "raises on non-hex digits" do
      expect_raises(ArgumentError) { Foundation::RGB.parse("#ZZZZZZ") }
    end
  end

  describe "#to_hex" do
    it "formats as lowercase #RRGGBB" do
      Foundation::RGB.new(0x7D_u8, 0x56_u8, 0xF4_u8).to_hex.should eq("#7d56f4")
    end

    it "round-trips through parse" do
      Foundation::RGB.parse("#7d56f4").to_hex.should eq("#7d56f4")
    end
  end

  describe "#to_lab" do
    it "maps black to L=0" do
      lab = Foundation::RGB.new(0_u8, 0_u8, 0_u8).to_lab
      lab.l.should eq(0.0)
      lab.a.should eq(0.0)
      lab.b.should eq(0.0)
    end

    it "maps white to L=100" do
      lab = Foundation::RGB.new(255_u8, 255_u8, 255_u8).to_lab
      lab.l.should be_close(100.0, 0.01)
      lab.a.should be_close(0.0, 0.01)
      lab.b.should be_close(0.0, 0.01)
    end

    it "matches the reference Lab for red" do
      lab = Foundation::RGB.parse("#FF0000").to_lab
      lab.l.should be_close(53.24, 0.1)
      lab.a.should be_close(80.09, 0.1)
      lab.b.should be_close(67.20, 0.1)
    end
  end
  describe "#distance" do
    it "is zero for identical colors" do
      clr = Foundation::RGB.parse("#7d56f4")
      clr.distance(clr).should eq(0.0)
    end

    it "is 100 between black and white" do
      black = Foundation::RGB.new(0_u8, 0_u8, 0_u8)
      white = Foundation::RGB.new(255_u8, 255_u8, 255_u8)
      black.distance(white).should be_close(100.0, 0.01)
    end

    it "ranks a near color closer than a far one" do
      target = Foundation::RGB.parse("#ff0000")
      near = Foundation::RGB.parse("#fe0000")
      far = Foundation::RGB.parse("#00ff00")
      (target.distance(near) < target.distance(far)).should be_true
    end
  end
end
