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

    # Renders *strings* through the bound style. Joins bound content, normalizes, applies the SGR core, shapes the block (padding, heigh, alignment, border, margins), then applies width+height limits.
    def render(strings : Array(String)) : String
      parts = strings.dup
      parts.unshift(@style.value) unless @style.value.empty?
      content = parts.join(' ')

      # pre-styling normalization order: tabs -> CRLF -> inline -> wrap
      content = expand_tabs(content)
      content = content.gsub("\r\n", "\n")
      content = content.delete('\n') if @style.inline?
      if !@style.inline? && @style.width_set? && @style.width > 0
        content = Foundation.wrap(content, @style.width - @style.horizontal_padding, "")
      end

      content = apply_sequence(sgr_sequence, content)

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

    # Builds the opening SGR sequence for the style's rules, or "" if none emit.
    private def sgr_sequence : String # ameba:disable Metrics/CyclomaticComplexity
      builder = Foundation::Style.new
      builder.bold if @style.bold?
      builder.faint if @style.faint?
      builder.italic if @style.italic?
      builder.underline if @style.underline?
      builder.reverse if @style.reverse?
      builder.blink if @style.blink?
      builder.strikethrough if @style.strikethrough?

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
    private def margin_sequence : String
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
    # Only targets attributes that affect blank cells, specificaly `reverse` and `background`.
    private def whitespace_sequence : String
      builder = Foundation::Style.new
      builder.reverse if @style.reverse?
      if @style.background_set?
        if bg = @style.background.try &.resolve(renderer)
          builder.background(bg)
        end
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
