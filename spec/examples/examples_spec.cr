require "../spec_helper"
require "../../examples/examples"

describe Examples do
  before_each do
    Examples.clear
  end

  describe "#run" do
    it "dispatches to a registered example" do
      Examples.register("spec/stub") { |_renderer| "stub output" }
      Examples.run("spec/stub", Sheen::Renderer.new(IO::Memory.new)).should eq("stub output")
    end

    it "passes the renderer through the example" do
      Examples.register("spec/echo-profile", &.color_profile.to_s)
      renderer = Sheen::Renderer.new(IO::Memory.new)
      renderer.color_profile = Foundation::Profile::TrueColor
      Examples.run("spec/echo-profile", renderer).should eq("TrueColor")
    end

    it "raises UnknownExample for an unregistered name" do
      expect_raises(Examples::UnknownExample, /missing-example/) do
        Examples.run("missing-example", Sheen::Renderer.new(IO::Memory.new))
      end
    end
  end

  describe "#names" do
    it "returns names in sorted order" do
      Examples.register("spec/zzz") { |_r| "" }
      Examples.register("spec/aaa") { |_r| "" }
      Examples.names.should eq(Examples.names.sort)
    end
  end
end
