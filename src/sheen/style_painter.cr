# TLDR; What functionality is in here?
# Style execution engine: runs the ordered Style pipeline from raw content through styled text to a fully shaped block.
require "../foundation"
require "./position"
require "./renderer"
require "./border_painter"

module Sheen
  # Renders a `Style` to a string. A short-lived collaborator constructed per render.
  # The pipeline is a sstateless transform over the bound and immutable `Style`, read through its getters.
  struct StylePainter
    def initialize(@style : Style)
    end

    # The renderer bound to the style, for color resolution.
    private def renderer : Renderer
      @style.renderer
    end

    # True when the active profile must not emit any SGR, either color or styling attributes.
    private def sgr_suppressed? : Bool
      profile = renderer.color_profile
      profile.no_tty? || profile.ascii?
    end

    # Renders *strings* through the bound style. Joins bound content, applies transforms, normalizes, applies the SGR core, shapes the block (padding, height, alignment, border, margins), then applies width+height limits.
    def render(strings : Array(String)) : String # ameba:disable Metrics/CyclomaticComplexity
      parts = strings.dup
      parts.unshift(@style.value) unless @style.value.empty?
      content = parts.join(' ')

      # A transform runs on the fully assembled content first, ahead of any normalization
      if fn = @style.transform
        content = fn.call(content)
      end

      # pre-styling normalization order: tabs -> CRLF -> inline -> wrap
      content = expand_tabs(content)
      content = content.gsub("\r\n", "\n")
      content = content.delete('\n') if @style.inline?
      if !@style.inline? && @style.width_set? && @style.width > 0
        content = Foundation.wrap(content, @style.width - @style.horizontal_padding, "")
      end

      content = apply_core(content)

      # post-styling block shaping order: padding -> height -> align -> border -> margins
      content = apply_padding(content) unless @style.inline?
      content = align_vertical_block(content) if @style.height > 0
      content = align_horizontal_block(content) if content.includes?('\n') || @style.width > 0
      content = BorderPainter.new(@style).apply(content) unless @style.inline?
      content = apply_margins(content) unless @style.inline?

      limit_height(limit_width(content))
    end

    # Expands tabs in *content* per the style's `tab_width`, applied even when no rules are set.
    private def expand_tabs(content : String) : String
      width = @style.tab_width
      case width
      when Style::NO_TAB_CONVERSION then content
      when 0                        then content.delete('\t')
      else                               content.gsub('\t', " " * width)
      end
    end

    # Builds the opening SGR sequence for the style's rules. Or "" if ehter none emit or this profile suppresses SGR sequences.
    private def sgr_sequence : String # ameba:disable Metrics/CyclomaticComplexity
      return "" if sgr_suppressed?

      builder = Foundation::Style.new
      case
      when @style.bold?          then builder.bold
      when @style.faint?         then builder.faint
      when @style.italic?        then builder.italic
      when @style.underline?     then builder.underline
      when @style.reverse?       then builder.reverse
      when @style.blink?         then builder.blink
      when @style.strikethrough? then builder.strikethrough
      end

      if @style.foreground_set? && (fg = @style.foreground.resolve(renderer))
        builder.foreground(fg)
      end
      if @style.background_set? && (bg = @style.background.resolve(renderer))
        builder.background(bg)
      end
      builder.to_s
    end

    # Wraps each line of *content* with *seq* and a reset, so styling resets at each newline.
    #
    # Returns content unchanged when *seq* is empty.
    private def apply_sequence(seq : String, content : String) : String
      return content if seq.empty?

      String.build do |io|
        lines = content.split('\n')
        lines.each_with_index do |line, i|
          io << seq << line << Foundation::RESET_STYLE
          io << '\n' if i < lines.size - 1
        end
      end
    end

    # Effective (as opposed to raw) "underline spaces": Follows the explicit toggle when set, otherwise follows `underline`.
    private def spaces_underlined? : Bool
      @style.underline_spaces_set? ? @style.underline_spaces? : @style.underline?
    end

    # Effective (as opposed to raw) "strikethrough spaces": Follows the explicit toggle when set, otherwise follows `strikethrough`.
    private def spaces_struck? : Bool
      @style.strikethrough_spaces_set? ? @style.strikethrough_spaces? : @style.strikethrough?
    end

    # Effective (as opposed to raw) "color whitespace": Follows the explicit toggle when set, otherwise true.
    private def whitespace_colored? : Bool
      @style.color_whitespace_set? ? @style.color_whitespace? : true
    end

    # True when spaces must be styled separately from the surrounding text. Eg decoration should, or should not, extend across them.
    #
    # Always false on profiles that suppress SGR.
    private def use_space_styler? : Bool
      return false if sgr_suppressed?

      (@style.underline? && !spaces_underlined?) ||
        (@style.strikethrough? && !spaces_struck?) ||
        spaces_underlined? || spaces_struck?
    end

    # Applies the core text styling to *content*, line by line.
    #
    # When spaces need a distinct styler, each rune is styled individually: spaces through the space styler, all others go through the main sequence. Otherwise each whole line is wrapped once as a single entity.
    private def apply_core(content : String) : String
      return apply_sequence(sgr_sequence, content) unless use_space_styler?

      text_seq = sgr_sequence
      space_seq = space_sequence
      content.split('\n').map do |line|
        String.build do |io|
          line.each_char do |chr|
            io << style_run(chr.whitespace? ? space_seq : text_seq, chr.to_s)
          end
        end
      end.join('\n')
    end

    # SGR sequence for individual space runes when the space styler is active.
    # Holds the foreground+background styling plus the space-appropriate styling attributes only (underline + strikethrough).
    #
    # Empty when the profile suppresses SGR.
    private def space_sequence : String
      return "" if sgr_suppressed?

      builder = Foundation::Style.new
      if @style.foreground_set? && (fg = @style.foreground.resolve(renderer))
        builder.foreground(fg)
      end
      if @style.background_set? && (bg = @style.background.resolve(renderer))
        builder.background(bg)
      end
      builder.underline if spaces_underlined?
      builder.strikethrough if spaces_struck?
      builder.to_s
    end

    # Adds left/right then top/bottom padding around already-styled *content*.
    #
    # L-R spaces carry the whitespace styler.
    # T-B blank lines are filled later by horizontal alignment.
    private def apply_padding(content : String) : String
      seq = whitespace_sequence
      content = pad_lines(content, -@style.padding_left, seq) if @style.padding_left > 0
      content = pad_lines(content, @style.padding_right, seq) if @style.padding_right > 0
      content = ("\n" * @style.padding_top) + content if @style.padding_top > 0
      content = content + ("\n" * @style.padding_bottom) if @style.padding_bottom > 0
      content
    end

    # Pads each line by *n* cells: negative on the left, positive on the right.
    # The space run is wrapped with *seq* styling.
    private def pad_lines(content : String, n : Int32, seq : String) : String
      spaces = style_run(seq, " " * n.abs)
      content.split('\n').map do |line|
        n > 0 ? line + spaces : spaces + line
      end.join('\n')
    end

    # Adds L/R then T/B margins around the shaped block containing *content*.
    # Margin space is filled to the block width and carries only the margin background.
    private def apply_margins(content : String) : String
      seq = margin_sequence
      content = pad_lines(content, -@style.margin_left, seq) if @style.margin_left > 0
      content = pad_lines(content, @style.margin_right, seq) if @style.margin_right > 0

      if @style.margin_top > 0 || @style.margin_bottom > 0
        spaces = " " * content.split('\n').max_of { |line| Foundation.string_width(line) }
        content = style_run(seq, (spaces + "\n") * @style.margin_top) + content if @style.margin_top > 0
        content = content + style_run(seq, ("\n" + spaces) * @style.margin_bottom) if @style.margin_bottom > 0
      end
      content
    end

    # SGR sequence for styling margin whitespace, background only. This is a separate sequence styler than `whitespace_sequence`.
    # Empty when the profile suppresses SGR.
    private def margin_sequence : String
      # This guard should never be necessary since the only input is a resolved bg, and color resolution already yeilds nothing under NoTTY/Ascii. But just to be safe.
      return "" if sgr_suppressed?

      builder = Foundation::Style.new
      if @style.margin_background_set?
        if bg = @style.margin_background.try &.resolve(renderer)
          builder.background(bg)
        end
      end
      builder.to_s
    end

    # Wraps *text* in *seq* and a reset.
    # Otherwise returns *text* unchanged when *seq* is empty.
    private def style_run(seq : String, text : String) : String
      seq.empty? ? text : "#{seq}#{text}#{Foundation::RESET_STYLE}"
    end

    # SGR sequence used to style inserted padding/alignment fill whitespace.
    # Only targets attributes that affect blank cells: `reverse` and `background`.
    # - reverse whenever the style is reversed
    # - foreground only under reverse
    # - background only when color_whitespace is on
    #
    # Empty when the profile suppresses SGR.
    private def whitespace_sequence : String
      return "" if sgr_suppressed?

      builder = Foundation::Style.new
      builder.reverse if @style.reverse?
      if @style.reverse? && @style.foreground_set? && (fg = @style.foreground.resolve(renderer))
        builder.foreground(fg)
      end

      if whitespace_colored? && @style.background_set? && (bg = @style.background.resolve(renderer))
        builder.background(bg)
      end
      builder.to_s
    end

    # Pads *content* with blank lines to reach the style's height, positioned per `align_vertical`.
    # A non-named position adds no block fill.
    private def align_vertical_block(content : String) : String
      str_height = content.count('\n') + 1
      gap = @style.height - str_height
      return content if gap <= 0

      case @style.align_vertical
      when Position::CENTER then ("\n" * (gap // 2)) + content + ("\n" * (gap - gap // 2))
      when Position::BOTTOM then ("\n" * gap) + content
      when Position::TOP    then content + ("\n" * gap)
      else                       content
      end
    end

    # Pads every line of *content* with spaces to the block width, positioned per `align_horizontal`.
    # Block width is defined by the widest line, or the style's width if larger.
    # Fill carries whitespace styling.
    private def align_horizontal_block(content : String) : String
      seq = whitespace_sequence
      lines = content.split('\n')
      block_width = {lines.max_of { |line| Foundation.string_width(line) }, @style.width}.max

      lines.map do |line|
        gap = block_width - Foundation.string_width(line)
        next line if gap <= 0

        case @style.align_horizontal
        when Position::RIGHT
          style_run(seq, " " * gap) + line
        when Position::CENTER
          style_run(seq, " " * (gap // 2)) + line + style_run(seq, " "*(gap - gap // 2))
        else
          line + style_run(seq, " " * gap)
        end
      end.join('\n')
    end

    # Truncates each line of *content* to the style's max_width visible cells.
    # Returns content unchanged when max_width is unset.
    private def limit_width(content : String) : String
      max = @style.max_width
      return content unless max > 0
      content.split('\n').map do |line|
        Foundation.truncate(line, max)
      end.join('\n')
    end

    # Keeps only the first of the style's max_height lines.
    # Returns content unchanged when max_height is unset.
    private def limit_height(content : String) : String
      max = @style.max_height
      return content unless max > 0
      content.split('\n').first(max).join('\n')
    end
  end
end
