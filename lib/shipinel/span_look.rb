# frozen_string_literal: true

# How a span of text is drawn (style, and where a link goes), and a piece
# of it measured in that look, ready for LineWrap to place.

require_relative "draw_list"
require_relative "geometry"
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

  # A piece of text measured in the look it is drawn with.
  class PlacedPiece
    attr_reader :text #: String
    attr_reader :width #: Float
    attr_reader :look #: SpanLook

    #: (String text, Float width, SpanLook look) -> void
    def initialize(text, width, look)
      @text = text
      @width = width
      @look = look
    end

    # Spaces at the start of a new line are not drawn.
    #: () -> bool
    def blank?
      @text.strip.empty?
    end

    # Adds the piece's decorations and text, drawn in `line`. Smaller text
    # (code) is centered on the line.
    #: (Flow flow, Rect line) -> void
    def add_to(flow, line)
      @look.decorate(line, flow)
      style = @look.style
      flow.add(TextRun.new(@text, line.band(style.line_height), style))
    end
  end
end
