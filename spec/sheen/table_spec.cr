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
