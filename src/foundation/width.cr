# TLDR; What functionality is in here?
# String geometry engine: measures, truncates, slices, and wraps visible terminal cells while preserving embedded ANSI escapes.
require "./ansi"
require "./unicode/east_asian_width"

module Foundation
  # Regional indicator codepoints, a pair forms one wide cluster flag emoji
  private REGIONAL_INDICATOR = 0x1F1E6..0x1F1FF
  # Variation Selector-16 forces wide emoji presentation
  private VARIATION_SELECTOR_16 = 0xFE0F

  # Default set of characters that are used to identify if a token can be split across lines.
  # A whitespace character is conspicuously absent here, but it's fine as that is assessed just prior to breakpoint processing in `.consume`
  private DEFAULT_BREAKPOINTS = "-"

  # Return the terminal cell-width of a single **grapheme** cluster:
  #
  # - 0 for zero-width control/combining
  # - 2 for wide East-Asian and emoji clusters
  # - 1 otherwise
  def self.grapheme_width(grapheme : String) : Int32
    return 0 if grapheme.empty?

    if grapheme.size == 1
      ch = grapheme[0]
      return 0 if ch.control? || ch.mark?
    end

    grapheme.each_char do |chr|
      ord = chr.ord
      return 2 if Unicode.wide?(ord) || ord == VARIATION_SELECTOR_16
    end

    return 2 if grapheme.size == 2 && grapheme.each_char.all? do |chr|
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

  # Truncate **string** to a visible width of at most **width**, appending **tail** when truncation occurs.
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

  # Truncate **string** from the left by **n** visible cells, prepending **prefix** when content is removed.
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

  # Accumulates wrapped output one grapheme at a time. Keeps track of what's already been written along with the pending buffered word and whitespace so word boundaries and hard-breaks can be decided as text streams in.
  #
  # Characters that can be considered as breakpoints for mid-word wrapping are provided by callers as a list of characters in a String. DEFAULT_BREAKPOINTS are always considered non-overrideable breakpoints.
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
      @sgr_state = SGRState.new
      @pending_sgr = [] of String
      @osc8_state = OSC8State.new
      @pending_osc8 = [] of String
    end

    # Feed one **grapheme** cluster of visible text.
    #
    # Processes newline, whitespace, and breakpoint characters appropriately. Any other character is treated as part of the current word.
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

    # Buffer an escape **sequence**, which attaches to the current word without affecting its width.
    #
    # SGR and OSC8 state stays pending until the word containing the sequence is committed to output which means we know which line it's rendered on.
    def consume_escape(kind : SegmentKind, sequence : String) : Nil
      @word += sequence
      @pending_sgr << sequence if kind.sgr?
      @pending_osc8 << sequence if kind.osc?
    end

    # Return the wrapped result after flushing pending content and closing out active terminal state.
    def finish : String
      flush_trailing_space
      flush_word
      close_hyperlink
      close_sgr
      @out.to_s
    end

    # Process a breakpoint **grapheme** mid-word. Keeps it inline if it fits the width constraints, otherwise defers to the next word buffer.
    private def add_break_point(grapheme : String) : Nil
      bp_width = Foundation.grapheme_width(grapheme)
      flush_space
      if @line_width + @word_width + bp_width > @width
        @word += grapheme
        @word_width += bp_width
      else
        flush_word
        @out << grapheme
        @line_width += bp_width
      end
    end

    # Append an ordinary **grapheme**, hard-break an over-length word and soft-wrap at word boundaries.
    private def add_word_char(grapheme : String) : Nil
      w = Foundation.grapheme_width(grapheme)
      flush_word if @word_width + w > @width
      @word += grapheme
      @word_width += w
      new_line if @line_width > 0 && @line_width + @word_width + @space_width > @width
    end

    # Force a hard newline break and start a fresh line.
    private def break_line : Nil
      flush_trailing_space
      flush_word
      new_line
    end

    # Commit pending whitespace at a line end. Keep if it fits, drop if it doesn't.
    private def flush_trailing_space : Nil
      return unless @word_width == 0
      @out << @space if @line_width + @space_width <= @width
      reset_space
    end

    # Commit pending space to output, adding its width to the line.
    private def flush_space : Nil
      @out << @space
      @line_width += @space_width
      reset_space
    end

    # Commit the pending word and its terminal state, preceded by any pending space, to output.
    private def flush_word : Nil
      return if @word.empty?

      flush_space
      @out << @word
      @pending_sgr.each { |sequence| @sgr_state.apply_sequence(sequence) }
      @pending_osc8.each { |sequence| @osc8_state.apply_sequence(sequence) }
      @line_width += @word_width
      reset_word
    end

    # Close active terminal state, emit a newline, and then restore that state in terminal-safe order at the start of the newline.
    # Because it's a newline, the current line width and pending space get reset.
    private def new_line : Nil
      close_sgr
      close_hyperlink
      @out << '\n'
      restore_hyperlink
      restore_sgr
      @line_width = 0
      reset_space
    end

    # Close out the accumulated active SGR state so it can't leak past the line boundary.
    private def close_sgr : Nil
      @out << RESET_STYLE if @sgr_state.active?
    end

    # Reconstruct the previous active accumulated SGR state after successfully passing a newline boundary.
    private def restore_sgr : Nil
      @out << @sgr_state.sequence if @sgr_state.active?
    end

    # Close out the active hyperlink either before a line boundary or at the end of output.
    private def close_hyperlink : Nil
      @out << @osc8_state.close_sequence
    end

    # Restore an active hyperlink after a line boundary.
    private def restore_hyperlink : Nil
      @out << @osc8_state.sequence
    end

    # Clear the pending word buffer, its accumulated width, and its uncommitted terminal state sequences.
    private def reset_word : Nil
      @word = ""
      @word_width = 0
      @pending_sgr.clear
      @pending_osc8.clear
    end

    # Clear the pending space buffer and its accumulated width.
    private def reset_space : Nil
      @space = ""
      @space_width = 0
    end

    # Assess if this is a whitespace grapheme that is not a Non-Breaking-SPace char.
    private def space?(grapheme : String) : Bool
      chr = grapheme[0]
      chr.whitespace? && chr.ord != NBSP
    end

    # Checks if this **grapheme** is a breakpoint.
    #
    # Any members of DEFAULT_BREAKPOINTS or any configured breakpoint character returns true. Otherwise false.
    private def break_point?(grapheme : String) : Bool
      DEFAULT_BREAKPOINTS.includes?(grapheme) ||
        @breakpoints.includes?(grapheme)
    end
  end

  # Wrap **string** to lines of at most **width** visible cells, preferring whitespace and configured breakpoints, hard-breaking longer tokens at grapheme boundaries. Width is measured in terminal cells over grapheme clusters.
  #
  # Regular whitespace and hyphens are always a breakpoint, as well as any character passed in to **breakpoints**.
  #
  # ANSI escape sequences are preserved as submitted. At the end of each line SGR is reset and then any OSC8 hyperlink is closed, and on the next line the hyperlink is reopened and SGR is restored.
  #
  # Returns **string** unchanged if width is less than 1.
  def self.wrap(string : String, width : Int32, breakpoints : String = DEFAULT_BREAKPOINTS) : String
    return string if width < 1

    wrapper = Wrapper.new(width, breakpoints)
    each_segment(string) do |kind, content|
      if kind.text?
        content.each_grapheme { |grapheme| wrapper.consume(grapheme.to_s) }
      else
        wrapper.consume_escape(kind, content)
      end
    end
    wrapper.finish
  end
end
