require "../spec_helper"

describe Sheen::Table::StringData do
  it "reports rows and columns and reads cells" do
    data = Sheen::Table::StringData.new([["a", "b"], ["c", "d"]])
    data.rows.should eq(2)
    data.columns.should eq(2)
    data.at(0, 1).should eq("b")
    data.at(1, 0).should eq("c")
  end

  it "grows columns to the widest appended row" do
    data = Sheen::Table::StringData.new
    data.append(["a"]).append(["b", "c", "d"])
    data.rows.should eq(2)
    data.columns.should eq(3)
  end

  it "builds a row from cells via item" do
    data = Sheen::Table::StringData.new.item("x", "y")
    data.rows.should eq(1)
    data.at(0, 1).should eq("y")
  end

  it "returns an empty string for out of range indices" do
    data = Sheen::Table::StringData.new([["a", "b"]])
    data.at(5, 0).should eq("")
    data.at(0, 9).should eq("")
    data.at(-1, 2).should eq("")
  end
end

describe Sheen::Table::Filter do
  it "keeps only rows the predicate rejects and reindexes over them" do
    data = Sheen::Table::StringData.new([["a"], ["b"], ["c"], ["d"]])
    filter = Sheen::Table::Filter.new(data).filter { |row| row != 2 }
    filter.rows.should eq(3)
    filter.at(2, 0).should eq("d")
  end

  it "passes every row until a predicate is set" do
    data = Sheen::Table::StringData.new([["a"], ["b"]])
    Sheen::Table::Filter.new(data).rows.should eq(2)
  end

  it "reports the wrapped data's column count" do
    data = Sheen::Table::StringData.new([["a", "b", "c"]])
    Sheen::Table::Filter.new(data).columns.should eq(3)
  end

  it "returns an empty string past the last passing row" do
    data = Sheen::Table::StringData.new([["a"], ["b"], ["c"], ["d"]])
    filter = Sheen::Table::Filter.new(data).filter { |row| row != 2 }
    filter.at(10, 0).should eq("")
  end

  it "reports zero rows when the predicate rejects everything" do
    data = Sheen::Table::StringData.new([["a"], ["b"]])
    filter = Sheen::Table::Filter.new(data).filter { |_row| false }
    filter.rows.should eq(0)
    filter.at(0, 0).should eq("")
  end
end

describe "Sheen::Table.data_to_matrix" do
  it "materializes data into a dense matrix, padding rows as needed" do
    data = Sheen::Table::StringData.new([["a", "b"], ["c"]])
    Sheen::Table.data_to_matrix(data).should eq([["a", "b"], ["c", ""]])
  end
end

describe Sheen::Table do
  it "defaults to a rounded border with all borders but row enabled and wrap on" do
    table = Sheen::Table.new
    table.border.should eq(Sheen::Border.rounded)
    table.border_top?.should be_true
    table.border_right?.should be_true
    table.border_bottom?.should be_true
    table.border_left?.should be_true
    table.border_header?.should be_true
    table.border_column?.should be_true
    table.border_row?.should be_false
    table.wrap?.should be_true
    table.use_manual_height?.should be_false
    table.data.rows.should eq(0)
    table.headers.empty?.should be_true
    table.width.should eq(0)
    table.offset.should eq(0)
  end

  it "appends rows and reads them back through the data source" do
    table = Sheen::Table.new.row("a", "b").row("c", "d")
    table.data.rows.should eq(2)
    table.data.at(1, 1).should eq("d")
  end

  it "appends multiple rows at once" do
    table = Sheen::Table.new.rows(["a", "b"], ["c", "d"])
    table.data.rows.should eq(2)
    table.data.at(0, 0).should eq("a")
  end

  it "sets headers" do
    Sheen::Table.new.headers("Name", "Age").headers.should eq(["Name", "Age"])
  end

  it "clears rows" do
    Sheen::Table.new.row("a").clear_rows!.data.rows.should eq(0)
  end

  it "swaps the data source" do
    data = Sheen::Table::StringData.new([["x"]])
    Sheen::Table.new.data(data).data.rows.should eq(1)
  end

  it "returns self from setters for chaining" do
    table = Sheen::Table.new
    table.border_row(true).should be(table)
  end

  it "records a manual height" do
    table = Sheen::Table.new.height(5)
    table.height.should eq(5)
    table.use_manual_height?.should be_true
  end

  it "resolves per-cell styles through the style block" do
    table = Sheen::Table.new.style do |row, _col|
      row == Sheen::Table::HEADER_ROW ? Sheen::Style.new.bold : Sheen::Style.new
    end
    table.cell_style(Sheen::Table::HEADER_ROW, 0).bold?.should be_true
    table.cell_style(0, 0).bold?.should be_false
  end

  it "returns a plain style by default" do
    Sheen::Table.new.cell_style(0, 0).bold?.should be_false
  end
end
