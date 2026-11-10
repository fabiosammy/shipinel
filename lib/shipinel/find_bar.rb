# frozen_string_literal: true

# The strip pinned to the bottom of the window while the find bar is open:
# "Find: " and what was typed, with a cursor after it, and on the right
# which match it is on ("2 of 7") or "no matches". It does not scroll; the
# page above it is shortened by its height.

require_relative "draw_list"
require_relative "font_set"
require_relative "geometry"
require_relative "search"
require_relative "styles"
require_relative "theme"

module Shipinel
  # See the file comment.
  class FindBar
    # Pixels above and below the line.
    PADDING = 8.0
    LABEL = "Find: "

    # @rbs @search: Search
    # @rbs @style: TextStyle
    # @rbs @area: Rect
    # @rbs @fonts: FontSet

    # `area` is the window's; `fonts` measure the text.
    #: (Search search, TextStyle style, Rect area, FontSet fonts) -> void
    def initialize(search, style, area, fonts)
      @search = search
      @style = style
      @area = area
      @fonts = fonts
    end

    # The height of an open bar with text in `style`.
    #: (TextStyle style) -> Float
    def self.room(style)
      style.line_height + (PADDING * 2)
    end

    # 0 while closed.
    #: () -> Float
    def height
      @search.open? ? FindBar.room(@style) : 0.0
    end

    # Into the overlay.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      return unless @search.open?

      band = Rect.new(0.0, @area.top + @area.height - height, @area.width, height)
      overlay.add(Box.new(band, Theme::Progress::BAND))
      add_query(overlay, band)
      add_count(overlay, band)
    end

    private

    # The text line inside `band`, from `left`, `width` wide.
    #: (Rect band, Float left, Float width) -> Rect
    def line(band, left, width)
      Rect.new(left, band.top + PADDING, width, @style.line_height)
    end

    # "Find: " and the query, then a thin bar where the next character goes.
    #: (DrawList overlay, Rect band) -> void
    def add_query(overlay, band)
      typed = "#{LABEL}#{@search.query}"
      width = @fonts.text_width(typed, @style)
      overlay.add(TextRun.new(typed, line(band, Theme::Spacing::MARGIN, width), @style))
      overlay.add(Box.new(line(band, Theme::Spacing::MARGIN + width + 1.0, 2.0), @style.color))
    end

    # "2 of 7" or "no matches" on the right; nothing before any typing.
    #: (DrawList overlay, Rect band) -> void
    def add_count(overlay, band)
      return if @search.query.empty?

      text = count_text
      width = @fonts.text_width(text, count_style)
      overlay.add(TextRun.new(text, line(band, band.width - Theme::Spacing::MARGIN - width, width), count_style))
    end

    # Amber when nothing matches.
    #: () -> TextStyle
    def count_style
      @style.with_color(@search.total.zero? ? Theme::Found::NONE : Theme::Ink::MUTED)
    end

    #: () -> String
    def count_text
      total = @search.total
      total.zero? ? "no matches" : "#{@search.current + 1} of #{total}"
    end
  end
end
