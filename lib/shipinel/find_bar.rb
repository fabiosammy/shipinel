# frozen_string_literal: true

# The strip pinned to the bottom of the window: while the find bar is open,
# "Find: " and what was typed, with a cursor after it, and on the right
# which match it is on ("2 of 7") or "no matches"; otherwise a status line
# saying how to get help. It does not scroll; the page above it is
# shortened by its height.

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

    # The status line says this while the find bar is closed.
    STATUS = "Press ? for help"

    #: () -> Float
    def height
      FindBar.room(@style)
    end

    # Into the overlay: the find bar, or the status line.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      overlay.add(Box.new(band, Theme::Progress::BAND))
      return add_status(overlay) unless @search.open?

      add_query(overlay)
      add_count(overlay)
    end

    private

    # "Press ? for help", muted, in the status line.
    #: (DrawList overlay) -> void
    def add_status(overlay)
      muted = @style.with_color(Theme::Ink::MUTED)
      overlay.add(TextRun.new(STATUS, line(Theme::Spacing::MARGIN, @fonts.text_width(STATUS, muted)), muted))
    end

    # The strip, along the bottom of the window.
    #: () -> Rect
    def band
      Rect.new(0.0, @area.top + @area.height - height, @area.width, height)
    end

    # The text line inside the strip, from `left`, `width` wide.
    #: (Float left, Float width) -> Rect
    def line(left, width)
      Rect.new(left, band.top + PADDING, width, @style.line_height)
    end

    # "Find: " and the query, then a thin bar where the next character goes.
    #: (DrawList overlay) -> void
    def add_query(overlay)
      typed = "#{LABEL}#{@search.query}"
      width = @fonts.text_width(typed, @style)
      overlay.add(TextRun.new(typed, line(Theme::Spacing::MARGIN, width), @style))
      overlay.add(Box.new(line(Theme::Spacing::MARGIN + width + 1.0, 2.0), @style.color))
    end

    # "2 of 7" or "no matches" on the right; nothing before any typing.
    #: (DrawList overlay) -> void
    def add_count(overlay)
      return if @search.query.empty?

      text = count_text
      width = @fonts.text_width(text, count_style)
      overlay.add(TextRun.new(text, line(@area.width - Theme::Spacing::MARGIN - width, width), count_style))
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
