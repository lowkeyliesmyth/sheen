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
end
