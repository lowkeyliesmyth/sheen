require "../spec_helper"

describe "Sheen measurement" do
  it "measures width as the widest line" do
    Sheen.width("hi\nthere").should eq(5)
  end

  it "ignores ANSI when measuring width" do
    Sheen.width("\e[1mhi\e[0m").should eq(2)
  end

  it "measures height by line count" do
    Sheen.height("a\nb\nc").should eq(3)
  end

  it "measures size as width and height" do
    Sheen.size("hi\nthere").should eq({5, 2})
  end
end

describe "Sheen.join_horizontal" do
  it "returns the single block unchanged" do
    Sheen.join_horizontal(Sheen::Position::TOP, "solo").should eq("solo")
  end

  it "joins side by side, top aligned" do
    Sheen.join_horizontal(Sheen::Position::TOP, "AAA\nAAA", "B")
      .should eq("AAAB\nAAA ")
  end

  it "joins side by side, bottom-aligned" do
    Sheen.join_horizontal(Sheen::Position::BOTTOM, "AAA\nAAA", "B")
      .should eq("AAA \nAAAB")
  end
end

describe "Sheen.join_vertical" do
  it "stacks blocks, left aligned" do
    Sheen.join_vertical(Sheen::Position::LEFT, "AA", "BBBB")
      .should eq("AA  \nBBBB")
  end

  it "stacks blocks, right aligned" do
    Sheen.join_vertical(Sheen::Position::RIGHT, "AA", "BBBB")
      .should eq("  AA\nBBBB")
  end

  it "stacks blocks, centered" do
    Sheen.join_vertical(Sheen::Position::CENTER, "CCCC", "DD")
      .should eq("CCCC\n DD ")
  end
end

private def renderer(profile : Foundation::Profile = Foundation::Profile::TrueColor) : Sheen::Renderer
  rnd = Sheen::Renderer.new(IO::Memory.new)
  rnd.color_profile = profile
  rnd
end

describe "Sheen.place_horizontal" do
  it "is a noop when the width fits the content" do
    Sheen.place_horizontal(2, Sheen::Position::LEFT, "hi").should eq("hi")
  end

  it "pads the right when left-positioned" do
    Sheen.place_horizontal(6, Sheen::Position::LEFT, "hi").should eq("hi    ")
  end

  it "pads the left when right-positioned" do
    Sheen.place_horizontal(6, Sheen::Position::RIGHT, "hi").should eq("    hi")
  end

  it "centers with the remainder on the right" do
    Sheen.place_horizontal(7, Sheen::Position::CENTER, "hi").should eq("  hi   ")
  end

  it "pads each line of a ragged block to the input width" do
    Sheen.place_horizontal(4, Sheen::Position::LEFT, "a\nbb").should eq("a   \nbb  ")
  end
end

describe "Sheen.place_vertical" do
  it "is a noop when the height fits the content" do
    Sheen.place_vertical(1, Sheen::Position::TOP, "hi").should eq("hi")
  end

  it "adds blank lines below when top-positioned" do
    Sheen.place_vertical(3, Sheen::Position::TOP, "hi").should eq("hi\n  \n  ")
  end

  it "adds blank lines above when bottom-positioned" do
    Sheen.place_vertical(3, Sheen::Position::BOTTOM, "hi").should eq("  \n  \nhi")
  end

  it "centers with the remainder on the bottom" do
    Sheen.place_vertical(4, Sheen::Position::CENTER, "hi").should eq("  \nhi\n  \n  ")
  end
end

describe "Sheen.place" do
  it "places on both axes" do
    Sheen.place(4, 3, Sheen::Position::CENTER, Sheen::Position::CENTER, "hi")
      .should eq("    \n hi \n    ")
  end
end

describe "whitespace styling" do
  it "fills whitespace with custom characters" do
    Sheen.place_horizontal(5, Sheen::Position::LEFT, "hi", ws_chars: ".")
      .should eq("hi...")
  end

  it "colors the fill with a background" do
    Sheen.place_horizontal(4, Sheen::Position::LEFT, "hi", ws_background: Sheen::RED, renderer: renderer)
      .should eq("hi\e[41m  \e[0m")
  end
end
