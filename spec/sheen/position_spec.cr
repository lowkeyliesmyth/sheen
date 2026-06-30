require "../spec_helper"

describe Sheen::Position do
  it "clamps fractions into 0.0..1.0 range" do
    Sheen::Position.new(-0.5).fraction.should eq(0.0)
    Sheen::Position.new(1.5).fraction.should eq(1.0)
    Sheen::Position.new(0.25).fraction.should eq(0.25)
  end

  it "names the cardinal positions" do
    Sheen::Position::LEFT.value.should eq(0.0)
    Sheen::Position::TOP.value.should eq(0.0)
    Sheen::Position::RIGHT.value.should eq(1.0)
    Sheen::Position::BOTTOM.value.should eq(1.0)
    Sheen::Position::CENTER.value.should eq(0.5)
  end
end
