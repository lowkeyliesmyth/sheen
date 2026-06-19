require "../../spec_helper"

describe Foundation::Unicode do
  describe "#wide?" do
    it "is true for CJK ideographs" do
      Foundation::Unicode.wide?('世'.ord).should be_true
    end

    it "is true for fullwidth forms" do
      Foundation::Unicode.wide?('Ａ'.ord).should be_true
    end

    it "is false for ASCII" do
      Foundation::Unicode.wide?('A'.ord).should be_false
    end

    it "is false for a combining mark (handled as zero-width elsewhere" do
      Foundation::Unicode.wide?(0x0301).should be_false
    end
  end
end
