# But who tests the tester? We do!
require "./examples_helper"

describe "examples_helper" do
  describe "ascii_renderer" do
    it "pins Ascii profile and a dark background" do
      renderer = ascii_renderer
      renderer.color_profile.should eq(Foundation::Profile::Ascii)
      renderer.has_dark_background?.should be_true
    end
  end

  describe "truecolor_renderer" do
    it "pins the TrueColor profile" do
      truecolor_renderer.color_profile.should eq(Foundation::Profile::TrueColor)
    end
  end

  describe "assert_within_width" do
    it "passes when every line fits" do
      assert_within_width("abc\nde\n", 3)
    end

    it "measures visible width, ignoring ANSI escapes" do
      assert_within_width("\e[31mabc\e[0m", 3)
    end

    it "fails when a line is too wide" do
      expect_raises(Spec::AssertionFailed) { assert_within_width("abcd", 3) }
    end
  end

  describe "assert_contains_stripped" do
    it "finds text hidden behind escape sequences" do
      assert_contains_stripped("\e[31mhello\e[0m", "hello")
    end

    it "fails when the text is absent" do
      expect_raises(Spec::AssertionFailed) { assert_contains_stripped("\e[31mhello\e[0m", "world") }
    end
  end
end
