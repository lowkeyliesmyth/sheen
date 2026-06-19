# sheen

TODO: Write a description here

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     sheen:
       github: lowkeyliesmyth/sheen
   ```

2. Run `shards install`

## Usage

```crystal
require "sheen"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

### Updating Unicode data

`data/unicode/EastAsianWidth.txt` is the vendored Unicode Character Database source for terminal-width measurement. Sheen uses the generated `src/foundation/unicode/east_asian_width.cr` and not downloaded data file.

To bump the supported Unicode version:

1. Update the `UNICODE_VERSION` constant in `scripts/gen_unicode.cr`.
2. Run `task unicode` to download the updated data file and generate the `east_asian_width.cr` table 
3. Commit both the refreshed data source and the updated lookup table + query method.


## Contributing

1. Fork it (<https://github.com/lowkeyliesmyth/sheen/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [lowkey](https://github.com/lowkeyliesmyth) - creator and maintainer
