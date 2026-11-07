# frozen_string_literal: true

# Breaks one block's text into lines on the page Flow is building, word by
# word, with each inline span in its own style.

require_relative "draw_list"
require_relative "geometry"
require_relative "markdown/inline"
require_relative "theme"

module Shipinel
  # Places one block's text word by word, starting a new line when the next
  # word would pass the right edge. A word longer than a whole line is left
  # to overflow rather than broken.
  class LineWrap
    # Example match: "ação " in "ação de teste" (a word with the spaces
    # after it), or a run of spaces.
    WORD = /\S+\s*|\s+/

    # @rbs @flow: Flow
    # @rbs @left: Float
    # @rbs @cursor: Float
    # @rbs @base: TextStyle

    #: (Flow flow, Float left, TextStyle base) -> void
    def initialize(flow, left, base)
      @flow = flow
      @left = left
      @cursor = left
      @base = base
    end

    #: (Markdown::Span span) -> void
    def write(span)
      style = style_for(span)
      # WORD has no groups, so scan yields Strings; to_s says so to Steep.
      span.text.scan(WORD).each { |word| place(word.to_s, style) }
      nil
    end

    private

    # **bold** keeps the size and color of the text around it; `code` is
    # always code-sized.
    #: (Markdown::Span span) -> TextStyle
    def style_for(span)
      case span.style
      when :bold then TextStyle.new(Theme::FontSlot::BOLD, @base.size, @base.color)
      when :code then @flow.styles.code_block
      else @base
      end
    end

    #: (String word, TextStyle style) -> void
    def place(word, style)
      width = @flow.width_of(word, style)
      new_line if @cursor > @left && @cursor + width > @flow.right
      return if @cursor == @left && word.strip.empty?

      draw(word, width, style)
    end

    #: () -> void
    def new_line
      @flow.gap(@base.line_height)
      @cursor = @left
      nil
    end

    # Smaller text (code) is centered on the line; code gets its background.
    #: (String word, Float width, TextStyle style) -> void
    def draw(word, width, style)
      line = Rect.new(@cursor, @flow.top, width, @base.line_height)
      @flow.add(Box.new(line, Theme::Surface::CODE_BACKGROUND)) if style.font_slot == Theme::FontSlot::MONO
      @flow.add(TextRun.new(word, line.band(style.line_height), style))
      @cursor += width
    end
  end
end
