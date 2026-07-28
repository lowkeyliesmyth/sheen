require "../spec_helper"

private def resize(table : Sheen::Table) : {Array(Int32), Array(Int32)}
  matrix = Sheen::Table.data_to_matrix(table.data)
  Sheen::TableResizer.new(table, matrix).resize
end

describe Sheen::TableResizer do
  it "sizes columns to their content and rows to one line when unconstrained" do
    table = Sheen::Table.new.headers("Name", "Age").row("Wally", "32").row("Iris", "29")
    widths, heights = resize(table)
    widths.should eq([5, 3])
    heights.should eq([1, 1, 1])
  end

  it "expands the shorter columns first to reach a target width" do
    table = Sheen::Table.new.headers("Name", "Age").row("Wally", "32").row("Iris", "29").width(12)
    widths, _ = resize(table)
    widths.should eq([5, 4]) # border characters contribute 3 columns
  end

  it "grows a row's height for multiline cell content" do
    table = Sheen::Table.new.row("a\nb\nc", "x")
    widths, heights = resize(table)
    widths.should eq([1, 1])
    heights.should eq([3])
  end

  it "grows a row's height when content wraps under a constrained width" do
    table = Sheen::Table.new.row("aaaaaaaa").width(5)
    _, heights = resize(table)
    heights[0].should be > 1
  end

  it "widens a column by its cells' horizontal padding" do
    table = Sheen::Table.new.row("Ab").style { |_row, _col| Sheen::Style.new.padding(0, 2) }
    widths, _ = resize(table)
    widths.should eq([6])
  end
end
