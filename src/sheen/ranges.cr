require "../foundation"
require "./style"

module Sheen
  # A visible-cell range matched with the style to apply to it.
  #
  # For `Sheen.style_ranges`, *start* is inclusive and *finish* is exclusive.
  record StyleRange, start : Int32, finish : Int32, style : Style

  # Applies *matched* Style to the runes of *str* at the given *indices*. The rest of the runes get the *unmatched* Style applied.
  # Each run of same-status runes are rendered as one styled group.
  #
  # Note that runes are Unicode codepoints and not grapheme clusters. Indices out of bounds are ignored.
  # Returns the reassembled and fully styled string.
  def self.style_runes(str : String, indices : Enumerable(Int32), matched : Style, unmatched : Style) : String
    set = indices.to_set
    String.build do |io|
      str.each_char.with_index.chunk { |_chr, i| set.includes?(i) }.each do |matches, group|
        style = matches ? matched : unmatched
        io << style.render(group.map(&.first).join)
      end
    end
  end

  # Styles visible-cell *ranges* of *str*, preserving any existing styling as-is in the gaps between ranges. *Ranges* must be ordered and not overlap.
  #
  # Each range has its text stripped of ANSI sequences, leaving only a printable content string.
  def self.style_ranges(str : String, ranges : Array(StyleRange)) : String
    return str if ranges.empty?

    stripped = Foundation.strip(str)
    last = 0
    String.build do |io|
      ranges.each do |range|
        io << Foundation.cut(str, last, range.start) if range.start > last
        io << range.style.render(Foundation.cut(stripped, range.start, range.finish))
        last = range.finish
      end
      io << Foundation.truncate_left(str, last)
    end
  end

  # :ditto:
  # Splat convenience version: `Sheen.style.ranges(str, r1, r2)`.
  # Requires at least one range. Use the array overload version for any possible empty case.
  def self.style_ranges(str : String, *ranges : StyleRange) : String
    style_ranges(str, ranges.to_a)
  end
end
