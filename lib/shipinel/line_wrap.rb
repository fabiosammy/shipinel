# frozen_string_literal: true

# Breaks one block's text into lines on the page Flow is building, word by
# word, with each inline span in its own style. A piece of a word that only
# the symbol font can draw (an emoji) is drawn in that font.

require_relative "draw_list"
require_relative "geometry"
require_relative "markdown/inline"
require_relative "span_look"
require_relative "theme"

module Shipinel
  # Places text piece by piece, starting a new line when the next piece
  # would pass the right edge. A word longer than a whole line (a long path
  # in a narrow table column) is broken between characters instead.
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
      look = SpanLook.for(span, style_for(span))
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
      when :italic then @base.with_font(Theme::FontSlot::ITALIC)
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
      placed = measure(piece, look)
      too_wide?(placed) ? piece.each_char { |char| place(char, placed.look) } : fit(placed)
      nil
    end

    #: (String piece, SpanLook look) -> PlacedPiece
    def measure(piece, look)
      look = look_for(piece.ord, look)
      PlacedPiece.new(piece, @flow.fonts.text_width(piece, look.style), look)
    end

    # Wider than a whole line, and more than one character to break.
    #: (PlacedPiece placed) -> bool
    def too_wide?(placed)
      placed.width > @flow.right - @left && placed.text.size > 1
    end

    #: (PlacedPiece placed) -> void
    def fit(placed)
      new_line if @cursor > @left && @cursor + placed.width > @flow.right
      return if @cursor == @left && placed.blank?

      draw(placed)
    end

    #: () -> void
    def new_line
      @flow.gap(@base.line_height)
      @cursor = @left
      nil
    end

    #: (PlacedPiece placed) -> void
    def draw(placed)
      width = placed.width
      placed.add_to(@flow, Rect.new(@cursor, @flow.top, width, @base.line_height))
      @cursor += width
    end
  end
end
