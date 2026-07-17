# Sheen Examples

Reference consumers of Sheen that do double duty as end-to-end test demonstrations. Run one and bask in its beautiful glory.

## Running

Using the taskfile helper:
``` bash
task example              # list registered examples
task example -- <name>    # render one example
task examples             # render every example
```

If you're going to run a bunch of example consumers (DEMO TIIIIME!), avoid the repeated compilation hit and just build the dispatcher binary to call it directly:

``` bash
crystal build examples/main.cr -o bin/examples  # build it
bin/examples layout                             # render the layout example
bin/examples all                                # render every example
```


## Adding an example consumer

1. Create a new `examples/<group>/<name>.cr` exposing
   `Examples::<Name>.render : String`.
    - Build styles with a plain `Sheen::Style.new` -- examples use the process-global `Sheen.renderer` exactly as a real consumer would.
2. Self-register the consumer at the end of that file:
   `Examples.register("<group>/<name>") { Examples::<Name>.render }`.
3. Add `require "./<group>/<name>"` to `examples/examples.cr`.
