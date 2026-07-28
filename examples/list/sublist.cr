require "../examples"

module Examples::List::Sublist
  # A nested list that exercises it all. Tables, lists, and trees baby!
  def self.render : String
    purple = Sheen::Style.new.foreground(Sheen.color("#875FFF")).margin_right(1)
    pink = Sheen::Style.new.foreground(Sheen.color("#FF87D7")).margin_right(1)
    base = Sheen::Style.new.margin_bottom(1).margin_left(1)
    faint = Sheen::Style.new.faint
    title_style = Sheen::Style.new.italic.foreground(Sheen.color("#FFF7DB"))

    dim = "#BCBCBC"
    highlight = "#EE6FF8"
    special = Sheen::AdaptiveColor.new("#43B6FD", "#73F59F")

    # Collapses to a single 5-step blend
    grid_start = Foundation::RGB.parse("#F25D94")
    grid_end = Foundation::RGB.parse("#643AFF")
    colors = Array.new(5) { |i| grid_start.blend(grid_end, i / 5.0).to_hex }

    # Shared enumerator and style functions reused by some of the sublists
    checklist_enum = ->(_items : Sheen::Children, index : Int32) do
      case index
      when 1 then "✓"
      else        "•"
      end
    end

    checklist_enum_style = ->(_items : Sheen::Children, index : Int32) do
      case index
      when 1 then Sheen::Style.new.foreground(special).padding_right(1)
      else        Sheen::Style.new.padding_right(1)
      end
    end

    checklist_style = ->(_items : Sheen::Children, index : Int32) do
      case index
      when 1
        Sheen::Style.new.strikethrough.foreground(Sheen::AdaptiveColor.new("#969B86", "#696969"))
      else
        Sheen::Style.new
      end
    end

    # Styles the repeated Sheen logo with the color grid. Clamping the index here because to gracefully handle any list having more entries than the grid has steps and causing an out of bounds index error.
    logo_style = ->(items : Sheen::Children, index : Int32) do
      color = colors[index.clamp(0, colors.size - 1)]
      if index == items.length - 1
        title_style.padding(1, 2).margin(0, 0, 1, 0).max_width(20).background(color)
      else
        title_style.padding(0, 5 - index, 0, index + 2).max_width(20).background(color)
      end
    end

    doc_enum = ->(_items : Sheen::Children, index : Int32) do
      index == 1 ? "|\n|" : " "
    end

    doc_item_style = ->(_items : Sheen::Children, index : Int32) do
      index == 1 ? base.foreground(highlight) : base.foreground(dim)
    end

    doc_enum_style = ->(_items : Sheen::Children, index : Int32) do
      index == 1 ? Sheen::Style.new.foreground(highlight) : Sheen::Style.new.foreground(dim)
    end

    history = "Crystal began in 2011 as an experiment to bring Ruby's expressiveness to a compiled, statically typed  language with no runtime penalties. Its first public release landed in 2014, and after years of refinement and iteration by the core team and community Crystal 1.0 shipped in 2021."

    # Pre-rendered blocks embedded as leaf items.
    roman_block = Sheen::Style.new.padding(1).render(
      Sheen::List.new("0.1.0", "0.20.0", "0.35.0", "1.0.0", "1.21.0")
        .enumerator(:roman)
        .render
    )

    history_block = Sheen::Style.new
      .bold
      .foreground(Sheen.color("#FAFAFA"))
      .background(Sheen.color("#7D56F4"))
      .align(Sheen::Position::CENTER, Sheen::Position::CENTER)
      .padding(1, 3)
      .margin(0, 1, 1, 1)
      .width(40)
      .render(history)

    shard_table = Sheen::Table.new
      .width(30)
      .border_style(purple.margin_right(0))
      .style do |_row, col|
        style = col == 0 ? Sheen::Style.new.align(Sheen::Position::CENTER) : Sheen::Style.new.align(Sheen::Position::RIGHT).padding_right(2)
        next style.bold.align(Sheen::Position::CENTER).padding_right(0) if Sheen::Table::HEADER_ROW
        style.faint
      end
      .headers("SHARD", "STARS")
      .row("invidious", "20806")
      .row("lucky", "2760")
      .row("kemal", "3880")
      .row("lavinmq", "980")
      .row("owasp-noir", "1360")

    documents = Sheen::List.new
      .enumerator(doc_enum)
      .item_style(&doc_item_style)
      .enumerator_style(&doc_enum_style)
      .item("README.md\n" + faint.render("1 day ago"))
      .item("shard.yml\n" + faint.render("2 days ago"))
      .item(".ameba.yml\n" + faint.render("14 days ago"))
      .item("Taskfile.yaml\n" + faint.render("10 minutes ago"))

    sublist_f = Sheen::List.new
      .enumerator_style(Sheen::Style.new.foreground(colors[3]).margin_right(1))
      .item("Releases: The Road to 1.0")
      .item(roman_block)
      .item(history_block)
      .item(shard_table)
      .item("Docs")
      .item(documents)
      .item("EOF?")

    sublist_e = Sheen::List.new
      .enumerator_style(Sheen::Style.new.foreground(colors[4]).margin_right(1))
      .item("\nSheen: Shiny crystal terminal styles\n-----")
      .item("Inspired by Charm LipGloss")
      .item("https://crystal-lang.org")
      .item(sublist_f)
      .item("shards install sheen\n")

    sublist_d = Sheen::List.new
      .enumerator_style(purple)
      .enumerator(:dash)
      .item_style(&logo_style)
      .item("Sheen")
      .item("Sheen")
      .item("Sheen")
      .item("Sheen")
      .item("Sheen")
      .item(sublist_e)
      .item("AND MOOOOORE!")

    dependencies = Sheen::List.new
      .item_style(&checklist_style)
      .enumerator_style(&checklist_enum_style)
      .enumerator(checklist_enum)
      .item("Ameba")
      .item("Spectator")
      .item("kyaml")
      .item("crux")
      .item(sublist_d)

    to_try = Sheen::List.new
      .item_style(&checklist_style)
      .enumerator_style(&checklist_enum_style)
      .enumerator(checklist_enum)
      .item("Lucky")
      .item("Grip")
      .item("HTMX")
      .item("LavinMQ")

    sublist_a = Sheen::List.new
      .enumerator_style(pink)
      .item("Shards to Try")
      .item(to_try)
      .item("Shards We Might Depend On")
      .item(dependencies)
      .item("So many lists")

    root = Sheen::List.new
      .enumerator_style(purple)
      .item("Crystal")
      .item("Shards")
      .item("Specs")
      .item("Macros")
      .item("Fibers")
      .item(sublist_a)
      .item("happy hacking, Sheen-a-rino")

    root.render
  end
end

Examples.register("list/sublist") { Examples::List::Sublist.render }
