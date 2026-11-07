# frozen_string_literal: true

# Breaks one block's text into lines on the page Flow is building, word by
# word, with each inline span in its own style. A piece of a word that only
# the symbol font can draw (an emoji) is drawn in that font.

require_relative "draw_list"
require_relative "geometry"
require_relative "markdown/inline"
require_relative "theme"

module Shipinel
  # How one span is drawn: its style and, for a link, where it goes ("").
  class SpanLook
    attr_reader :style #: TextStyle
    attr_reader :url #: String

    #: (TextStyle style, String url) -> void
    def initialize(style, url)
      @style = style
      @url = url
    end

    # The same look in the symbol font, for an emoji inside the span.
    #: () -> SpanLook
    def as_symbol
      SpanLook.new(@style.with_font(Theme::FontSlot::SYMBOL), @url)
    end

    # What goes under a piece of text drawn in `line`: a code background,
    # or a link's underline and the area a click opens it from.
    #: (Rect line, Flow flow) -> void
    def decorate(line, flow)
      flow.add(Box.new(line, Theme::Surface::CODE_BACKGROUND)) if @style.font_slot == Theme::FontSlot::MONO
      return if @url.empty?

      flow.add(Box.new(line.underline(@style.line_height, @style.size), Theme::Accent::LINK))
      flow.add(LinkArea.new(line, @url))
    end
  end

  # Places text piece by piece, starting a new line when the next piece
  # would pass the right edge. A word longer than a whole line is left to
  # overflow rather than broken.
  class LineWrap
    # Example match: "ação " in "ação de teste" (a word with the spaces
    # after it), or a run of spaces.
    WORD = /\S+\s*|\s+/
    # Zero-width joiner and emoji variation selector: invisible, and no font
    # here has a glyph for them.
    INVISIBLE = "‍️"

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
      look = SpanLook.new(style_for(span), span.url)
      # WORD has no groups, so scan yields Strings; to_s says so to Steep.
      span.text.delete(INVISIBLE).scan(WORD).each { |word| place_word(word.to_s, look) }
      nil
    end

    private

    #: (String word, SpanLook look) -> void
    def place_word(word, look)
      @flow.fonts.pieces(word).each { |piece| place(piece, look) }
      nil
    end

    # **bold** keeps the size and color of the text around it; `code` is
    # always code-sized; a link keeps the size in the link color.
    #: (Markdown::Span span) -> TextStyle
    def style_for(span)
      case span.style
      when :bold then @base.with_font(Theme::FontSlot::BOLD)
      when :code then @flow.styles.code_block
      when :link then @base.with_color(Theme::Accent::LINK)
      else @base
      end
    end

    # A piece whose first character only the symbol font can draw uses
    # that font (FontSet cuts pieces where the font changes).
    #: (Integer codepoint, SpanLook look) -> SpanLook
    def look_for(codepoint, look)
      @flow.fonts.symbol?(codepoint) ? look.as_symbol : look
    end

    #: (String piece, SpanLook look) -> void
    def place(piece, look)
      look = look_for(piece.ord, look)
      width = @flow.fonts.text_width(piece, look.style)
      new_line if @cursor > @left && @cursor + width > @flow.right
      return if @cursor == @left && piece.strip.empty?

      draw(piece, width, look)
    end

    #: () -> void
    def new_line
      @flow.gap(@base.line_height)
      @cursor = @left
      nil
    end

    # Smaller text (code) is centered on the line.
    #: (String piece, Float width, SpanLook look) -> void
    def draw(piece, width, look)
      line = Rect.new(@cursor, @flow.top, width, @base.line_height)
      look.decorate(line, @flow)
      style = look.style
      @flow.add(TextRun.new(piece, line.band(style.line_height), style))
      @cursor += width
    end
  end
end
