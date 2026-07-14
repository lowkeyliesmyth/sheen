# sheen

> Shiny crystal terminal styles.

Sheen is a declarative terminal styling and layout library for Crystal. It lets you build styled CLI output and TUI views with an immutable, CSS-like API instead of hand-rolled ANSI escape sequences.

Inspired by our friends Charm who built [lipgloss](https://github.com/charmbracelet/lipgloss).

TODO: screenshot output here.

## Why sheen?

- **Immutable styles.** Every setter returns a new style, so you can safely reuse a base style across components without side effects.
- **Terminal-aware color rendering.** Hex and ANSI 256 colors degrade automatically to the capabilities of the terminal. `NO_COLOR` and `FORCE_COLOR` are honored.
- **Built-in terminal primitives.** ANSI/SGR generation, color-space math and downsampling, color-profile detection, and Unicode-aware width measurement are included, so styling and layout behave correctly across terminals.
- **CSS-like box model.** Padding, margins, width, height, alignment, and borders compose the way you expect.
- **Layout primitives.** Join blocks horizontally or vertically, place content inside sized boxes, and measure rendered dimensions.

## Installation

1. Add sheen to your `shard.yml`:

```yaml
dependencies:
  sheen:
    github: lowkeyliesmyth/sheen
```

2. Then run `shards install`

## Quick start

```crystal
require "sheen"

box = Sheen.style do |s|
  s.bold
  s.foreground "#FAFAFA"
  s.background "#7D56F4"
  s.padding 2
  s.width 24
  s.height 7
  s.align Sheen::Position::CENTER, Sheen::Position::CENTER
end

puts box.render("Hello, Crystal")
```

TODO: screenshot output here.


The same style built fluently:

```crystal
box = Sheen::Style.new
  .bold
  .foreground("#FAFAFA")
  .background("#7D56F4")
  .padding(2)
  .width(24)
  .height(7)
  .align(Sheen::Position::CENTER, Sheen::Position::CENTER)
```

## Examples

Take a look at some fully-fledged and runnable examples in the [`examples/`](examples/) directory. Run one with:

```bash
crystal run examples/main.cr -- <example-name>
```

Run the command without arguments to see the available example consumers.

## Feature tour

### Declarative styles

Build a style by chaining rules or by using the block builder.

```crystal
error = Sheen::Style.new
  .bold
  .foreground("#FF5F87")
  .background("#262626")
  .padding(1, 2)

puts error.render("Disk full")
```

Bind reusable content with `#string` and render the style with ad-hoc content later:

```crystal
label = Sheen::Style.new
  .foreground("#7D56F4")
  .bold
  .string("status:")

puts label.render(" ready")
puts label.render(" busy")
```

### Color profiles and adaptive colors

Sheen detects the terminal's color capability and automatically downsamples to the most robust option available. You can also force a profile if you want to.

```crystal
# Force True Color output
Sheen.renderer.color_profile = Foundation::Profile::TrueColor

puts Sheen::Style.new.foreground("#7D56F4").render("rich purple")
```

For light and dark terminal backgrounds, use adaptive colors:

```crystal
fg = Sheen::AdaptiveColor.new(light: "#000000", dark: "#FFFFFF")
puts Sheen::Style.new.foreground(fg).render("legible everywhere")
```

Or use complete colors if you need to control on a per-profile basis:

```crystal
accent = Sheen::CompleteColor.new(
  true_color: "#7D56F4",
  ansi256: "99",
  ansi: "5"
)

puts Sheen::Style.new.foreground(accent).render("consistent")
```

### Box model

Padding, margins, width, height, and alignment follow CSS shorthand conventions. So if you can ~~dodge a wrench~~ write CSS you'll be right at home.

```crystal
card = Sheen::Style.new
  .width(40)
  .padding(1, 2)
  .margin(1)
  .border(Sheen::Border.rounded)
  .border_foreground("#7D56F4")

puts card.render("Look at all the padding this baby can hold inside! And a margin outside too!")
```

### Borders

Pick from built-in border styles or define your own.

```crystal
Sheen::Border.normal   # ┌─┐
Sheen::Border.rounded  # ╭─╮
Sheen::Border.thick    # ┏━┓
Sheen::Border.double   # ╔═╗
Sheen::Border.hidden   # invisible frame
Sheen::Border.ascii    # +-+
```

Toggle activating individual sides with the `border` shorthand:

```crystal
Sheen::Style.new
  .border(Sheen::Border.thick, true, false, true, false) # top and bottom only
  .render("section divider")
```

### Inheritance and composition

Styles inherit only unset rules from a parent style, which makes it simple to define a base theme and then override each component as you need to.

```crystal
base = Sheen::Style.new.foreground("#CCCCCC").italic

notice = base.foreground("#FFD700")  # overrides foreground, keeps italic
quiet  = base.faint                  # keeps base foreground and italic
```

### Layout utilities

Join rendered blocks along an edge:

```crystal
left  = Sheen::Style.new.foreground("#FF5F87").render("ERROR")
right = Sheen::Style.new.render("Something went wrong")

puts Sheen.join_horizontal(Sheen::Position::CENTER, left, right)
```

Place content inside a sized box:

```crystal
Sheen.place(
  30, 10,
  Sheen::Position::CENTER,
  Sheen::Position::CENTER,
  "Loading..."
)
```

Measure rendered blocks:

```crystal
block = card.render("Some text")
w, h  = Sheen.size(block)
```

### Rendering control

Bind content, render on demand, and constrain output:

```crystal
tag = Sheen::Style.new
  .bold
  .foreground("#262626")
  .background("#7D56F4")
  .string("v1.0.0")

puts tag.render # v1.0.0
```

Force single-line output or cap rendered dimensions:

```crystal
Sheen::Style.new.inline.max_width(10).render("long sentence")
Sheen::Style.new.max_width(20).max_height(4).render(a_long_paragraph)
```

### Custom renderers

When rendering to multiple outputs, sheen supports creating a renderer per target so each gets its own profile and background detection.

```crystal
renderer = Sheen::Renderer.new(io)
style    = Sheen::Style.new(renderer)
  .background(Sheen::AdaptiveColor.new(light: "63", dark: "228"))

io << style.render("client-specific output")
```

## Coming next

Table, list, and tree rendering sub-packages are WIP, fam.

## Development

```bash
# Run the test suite
task spec

# Run the linter
task lint

# Format code
crystal tool format

```

### Updating Unicode data

More of a note to self, as nobody else should ever have to run this.

The vendored Unicode Character Database source for terminal-width measurement is stored at `data/unicode/EastAsianWidth.txt`. Sheen uses the generated `src/foundation/unicode/east_asian_width.cr` and not the downloaded data file.  

To bump the supported Unicode version:

1. Update the `UNICODE_VERSION` constant in `scripts/gen_unicode.cr`.
2. Run `task unicode` to download the updated data file and generate the `east_asian_width.cr` table.
3. Commit both the refreshed data source and the updated lookup table + query method.

## Contributing

Ran into a problem? Issues are welcome. Or if you're inclined to file a PR, see [CONTRIBUTING.md](CONTRIBUTING.md) to get set up.

## Contributors

- [lowkey](https://github.com/lowkeyliesmyth) — creator and maintainer
 
## License

MIT License — see [LICENSE](LICENSE) for details.

## References

- [sheen API documentation](https://lowkeyliesmyth.github.io/sheen/Sheen.html)
