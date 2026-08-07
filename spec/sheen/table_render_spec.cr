require "../spec_helper"

private def lang_table : Sheen::Table
  Sheen::Table.new
    .border(Sheen::Border.normal)
    .headers("LANGUAGE", "KIND", "GREETING")
    .style do |row, _col|
      base = Sheen::Style.new.padding(0, 1)
      row == Sheen::Table::HEADER_ROW ? base.align(Sheen::Position::CENTER) : base
    end
end

private def people_table : Sheen::Table
  Sheen::Table.new
    .headers("NAME", "AGE")
    .row("Alice", "30")
    .row("Bob", "25")
    .style do |row, _col|
      base = Sheen::Style.new.padding(0, 1)
      row == Sheen::Table::HEADER_ROW ? base.align(Sheen::Position::CENTER) : base
    end
end

describe "Sheen::Table#render" do
  it "renders a bordered table with padding, centered headers, and handles double-width CJK cells" do
    table = lang_table
      .row("Crystal", "Compiled", "안녕하세요")
      .row("Ruby", "Dynamic", "こんにちは")
      .row("Golang", "Compiled", "你好")
      .row("Rust", "Compiled", "やあ")
      .row("Python", "Dynamic", "สวัสดี")

    table.render.should eq(<<-TABLE.rstrip)
      ┌──────────┬──────────┬────────────┐
      │ LANGUAGE │   KIND   │  GREETING  │
      ├──────────┼──────────┼────────────┤
      │ Crystal  │ Compiled │ 안녕하세요 │
      │ Ruby     │ Dynamic  │ こんにちは │
      │ Golang   │ Compiled │ 你好       │
      │ Rust     │ Compiled │ やあ       │
      │ Python   │ Dynamic  │ สวัสดี       │
      └──────────┴──────────┴────────────┘
      TABLE
  end

  it "renders headers with a separator and no data rows" do
    lang_table.render.should eq(<<-TABLE.rstrip)
      ┌──────────┬──────┬──────────┐
      │ LANGUAGE │ KIND │ GREETING │
      ├──────────┼──────┼──────────┤
      └──────────┴──────┴──────────┘
      TABLE
  end

  it "renders a markdown border with the top and bottom rules off" do
    people_table
      .border(Sheen::Border.markdown)
      .border_top(false)
      .border_bottom(false)
      .render.should eq(<<-TABLE.rstrip)
        | NAME  | AGE |
        |-------|-----|
        | Alice | 30  |
        | Bob   | 25  |
        TABLE
  end

  it "renders an ASCII border" do
    people_table
      .border(Sheen::Border.ascii)
      .render.should eq(<<-TABLE.rstrip)
        +-------+-----+
        | NAME  | AGE |
        +-------+-----+
        | Alice | 30  |
        | Bob   | 25  |
        +-------+-----+
        TABLE
  end

  it "applies per-column alignment through the style block" do
    Sheen::Table.new
      .border(Sheen::Border.normal)
      .headers("LEFT", "RIGHT")
      .row("a", "b")
      .row("ccc", "DDD")
      .style do |row, col|
        style = Sheen::Style.new.padding(0, 1)
        next style.align(Sheen::Position::CENTER) if row == Sheen::Table::HEADER_ROW
        col == 1 ? style.align(Sheen::Position::RIGHT) : style
      end
      .render.should eq(<<-TABLE.rstrip)
        ┌──────┬───────┐
        │ LEFT │ RIGHT │
        ├──────┼───────┤
        │ a    │     b │
        │ ccc  │   DDD │
        └──────┴───────┘
        TABLE
  end

  it "wraps cell content wider than the column and grows the row height" do
    Sheen::Table.new
      .border(Sheen::Border.normal)
      .row("one two three")
      .style { |_row, _col| Sheen::Style.new.padding(0, 1).width(9) }
      .render.should eq(<<-TABLE.rstrip)
        ┌─────────┐
        │ one two │
        │ three   │
        └─────────┘
        TABLE
  end

  it "treats a CRLF line break the same as a newline" do
    Sheen::Table.new
      .border(Sheen::Border.normal)
      .row("Sub\r\nMarine")
      .style { |_row, _col| Sheen::Style.new.padding(0, 1).width(8) }
      .render.should eq(<<-TABLE.rstrip)
        ┌────────┐
        │ Sub    │
        │ Marine │
        └────────┘
        TABLE
  end
end
