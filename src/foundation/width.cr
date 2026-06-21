require "./ansi"
require "./unicode/east_asian_width"

module Foundation
  # Regional indicator codepoints, a pair forms one wide cluster flag emoji
  private REGIONAL_INDICATOR = 0x1F1E6..0x1F1FF
  # Variation Selector-16 forces wide emoji presentation
  private VARIATION_SELECTOR_16 = 0xFE0F

  # Returns the terminal cell-width of a single grapheme *cluster*:
  #
  # - 0 for zero-width control/combining
  # - 2 for wide East-Asian and emoji clusters
  # - 1 otherwise
  def self.grapheme_width(grapheme : String) : Int32
    return 0 if grapheme.empty?
    chars = grapheme.chars

    if chars.size == 1
      ch = chars[0]
      return 0 if ch.control? || ch.mark?
    end

    return 2 if chars.any? do |chr|
                  Unicode.wide?(chr.ord)
                end
    return 2 if chars.any? do |chr|
                  chr.ord == VARIATION_SELECTOR_16
                end
    return 2 if chars.size == 2 && chars.all? do |chr|
                  REGIONAL_INDICATOR.includes?(chr.ord)
                end
    1
  end

  # Returns visible width of *string* in terminal cells.
  # Grapheme clusters are the measurement unit, ANSI escape sequences count as zero.
  def self.string_width(string : String) : Int32
    width = 0
    strip(string).each_grapheme do |grapheme|
      width += grapheme_width(grapheme.to_s)
    end
    width
  end

  # Truncates *string* to a visible width of at most *width*, appending *tail* when truncation occurs.
  # ANSI escape sequences are never broken. Width is measured in terminal cells over grapheme clusters.
  def self.truncate(string : String, width : Int32, tail : String = "") : String
    return string if string_width(string) <= width

    limit = width - string_width(tail)
    return "" if limit < 0

    cur = 0
    ignoring = false
    String.build do |io|
      each_segment(string) do |kind, content|
        unless kind.text?
          io << content
          next
        end
        content.each_grapheme do |grapheme|
          gs = grapheme.to_s
          gw = grapheme_width(gs)
          if cur + gw > limit && !ignoring
            ignoring = true
            io << tail
          end
          next if ignoring
          cur += gw
          io << gs
        end
      end
    end
  end

  # Truncate *string* from the left by *n* visible cells, prepending *prefix* when content is removed.
  # ANSI escape sequences from the removed region are preserved so leading style is always retained.
  def self.truncate_left(string : String, n : Int32, prefix : String = "") : String
    return string if n <= 0

    cur = 0
    ignoring = true
    String.build do |io|
      each_segment(string) do |kind, content|
        unless ignoring
          io << content
          next
        end
        unless kind.text?
          io << content
          next
        end
        content.each_grapheme do |grapheme|
          gs = grapheme.to_s
          if ignoring
            cur += grapheme_width(gs)
            if cur > n
              ignoring = false
              io << prefix
              io << gs
            end
          else
            io << gs
          end
        end
      end
    end
  end

  # Returns the slice of *string* between visible cell positions *start* (inclusive) and *finish* (exclusive), preserving ANSI sequences.
  def self.cut(string : String, start : Int32, finish : Int32) : String
    return "" if finish <= start
    return truncate(string, finish, "") if start == 0
    truncate_left(truncate(string, finish, ""), start, "")
  end
end
