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

  # Accumulates wrapped output one grapheme at a time. Holds the committed outputs plus the pending word and whitespace runs, so word boundaries and hard-breaks can be decided as content streams in.
  private class Wrapper
    # Non-breaking space. Treated as a word character and never as a break
    NBSP = 0xA0

    def initialize(@width : Int32, @breakpoints : String)
      @out = String::Builder.new
      @line_width = 0
      @word = ""
      @word_width = 0
      @space = ""
      @space_width = 0
    end

    # Feeds one grapheme cluster of visible text.
    def consume(grapheme : String) : Nil
      if grapheme == "\n"
        break_line
      elsif space?(grapheme)
        flush_word
        @space += grapheme
        @space_width += Foundation.grapheme_width(grapheme)
      elsif break_point?(grapheme)
        add_break_point(grapheme)
      else
        add_word_char(grapheme)
      end
    end

    # Feeds an escape sequence, which attaches to the current word without affecting its width.
    def add_escape(sequence : String) : Nil
      @word += sequence
    end

    # Returns the wrapped result, flushing any pending word and trailing space.
    def finish : String
      flush_trailing_space
      flush_word
      @out.to_s
    end

    # Appends a breakpoint grapheme: kept inline if it fits otherwise deferred into the current word so it wraps with the following text
    private def add_break_point(grapheme : String) : Nil
      w = Foundation.grapheme_width(grapheme)
      flush_space
      if @line_width + @word_width + w > @width
        @word += grapheme
        @word_width += w
      else
        flush_word
        @out << grapheme
        @line_width += w
      end
    end

    # Appends an ordinary grapheme, hard-breaking an over-length word and soft-wrapping at word boundaries.
    private def add_word_char(grapheme : String) : Nil
      w = Foundation.grapheme_width(grapheme)
      flush_word if @word_width + w > @width
      @word += grapheme
      @word_width += w
      new_line if @line_width + @word_width + @space_width > @width
    end

    # Handles an explicit line break in the source
    private def break_line : Nil
      flush_trailing_space
      flush_word
      new_line
    end

    # Commits pending whitespace at a line end: kept if it fits, dropped if it doesn't.
    private def flush_trailing_space : Nil
      return unless @word_width == 0
      @out << @space if @line_width + @space_width <= @width
      reset_space
    end

    private def flush_space : Nil
      @out << @space
      @line_width += @space_width
      reset_space
    end

    # Commits the pending word to output, preceded by any pending space.
    private def flush_word : Nil
      return if @word.empty?
      flush_space
      @out << @word
      @line_width += @word_width
      reset_word
    end

    # Emits a newline and resets the current line width and pending space.
    private def new_line : Nil
      @out << '\n'
      @line_width = 0
      reset_space
    end

    # Clears the pending word buffer and its accumulated width.
    private def reset_word : Nil
      @word = ""
      @word_width = 0
    end

    # Clears the pending space buffer and its accumulated width.
    private def reset_space : Nil
      @space = ""
      @space_width = 0
    end

    # A whitespace grapheme that is not a non-breaking space
    private def space?(grapheme : String) : Bool
      chr = grapheme[0]
      chr.whitespace? && chr.ord != NBSP
    end

    # Checks if this grapheme is a breakpoint.
    #
    # A hyphen (always and by default) or any configured breakpoint character returns true. Otherwise false.
    private def break_point?(grapheme : String) : Bool
      grapheme == "-" || @breakpoints.each_char.any? { |brk| grapheme.includes?(brk) }
    end
  end

  # Wraps *string* to lines of at most *width* visible cells, preferring word boundaries and hard-breaking tokens longer than *width*. Width is measured in terminal cells over grapheme clusters.
  #
  # ANSI escape sequences and OSC8 hyperlinks are preserved across breaks.
  # A hypen is always a breakpoint, as well as any character in *breakpoints*.
  def self.wrap(string : String, width : Int32, breakpoints : String = " -") : String
    return string if width < 1

    wrapper = Wrapper.new(width, breakpoints)
    each_segment(string) do |kind, content|
      if kind.text?
        content.each_grapheme { |grapheme| wrapper.consume(grapheme.to_s) }
      else
        wrapper.add_escape(content)
      end
    end
    wrapper.finish
  end
end
