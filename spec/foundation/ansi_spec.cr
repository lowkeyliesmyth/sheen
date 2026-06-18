require "../spec_helper"

describe "#strip" do
  it "returns plain strings unchanged" do
    Foundation.strip("hello").should eq("hello")
  end

  it "removes SGR sequences" do
    Foundation.strip("\e[1;31mred\e[0m").should eq("red")
  end

  it "removes OSC hyperlink sequences" do
    Foundation.strip("\e]8;;https://example.com\e\\click\e]8;;\e\\").should eq("click")
  end

  it "removes OSC terminated by BEL" do
    Foundation.strip("\e]0;title\atext").should eq("text")
  end

  it "removes two-byte ESX sequences" do
    Foundation.strip("a\eMb").should eq("ab")
  end

  it "handless strings with no esxapes and unicode content" do
    Foundation.strip("héllo 世界 🎉").should eq("héllo 世界 🎉")
  end

  it "strips back to back sequences without gobbling printable text between" do
    Foundation.strip("\e[1ma\e[0mb\e[31mc").should eq("abc")
  end
end

describe "#set_hyperlink" do
  it "wraps a URL with no params" do
    Foundation.set_hyperlink("https://example.com").should eq("\e]8;;https://example.com\e\\")
  end

  it "encodes a single id param" do
    Foundation.set_hyperlink("https://example.com", id: "abc").should eq("\e]8;id=abc;https://example.com\e\\")
  end

  it "joins multiple params with :" do
    result = Foundation.set_hyperlink("https://example.com", id: "abc", title: "Example")
    result.should eq("\e]8;id=abc:title=Example;https://example.com\e\\")
  end

  it "accepts an empty URL" do
    Foundation.set_hyperlink("").should eq("\e]8;;\e\\")
  end

  describe "RESET_HYPERLINK constant" do
    it "matches an empty-params, empty-url hyperlink sequence" do
      Foundation::RESET_HYPERLINK.should eq("\e]8;;\e\\")
      Foundation::RESET_HYPERLINK.should eq(Foundation.set_hyperlink(""))
    end
  end

  describe "ST constant" do
    it "is the OSC string terminator, baby" do
      Foundation::ST.should eq("\e\\")
    end
  end
end
