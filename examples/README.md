# Sheen Examples

Reference consumers of Sheen that do double duty as end-to-end tests. Each example is a pure function `Sheen::Renderer -> String`, registered by name and exercised from `spec/examples/`.

## Running

    crystal run examples/main.cr -- <example>   # render one example to STDOUT

Run with no argument to list the registered examples:

``` bash
crystal run examples/main.cr
```

Or run a specific example with:

``` bash
crystal run examples/main.cr -- <example-name>
```

## Adding an example consumer

1. Create a new `examples/<group>/<name>.cr` exposing
   `Examples::<Name>.render(renderer : Sheen::Renderer) : String`.
2. Self-register the consumer at the end of that file:
   `Examples.register("<group>/<name>") { |r| Examples::<Name>.render(r) }`.
3. Add `require "./<group>/<name>"` to `examples/examples.cr`.
4. Add a spec for the consumer example under `spec/examples/`.
