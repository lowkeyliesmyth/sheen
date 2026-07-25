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
end
