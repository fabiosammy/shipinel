# frozen_string_literal: true

# Where the scrollbar is drawn for a page in a window, scrolled to an
# offset: a track along the right edge and a thumb as tall as the share of
# the page the window shows. Pure geometry; Scroll moves the page.

require_relative "draw_list"
require_relative "geometry"
require_relative "theme"

module Shipinel
  # See the file comment.
  class Scrollbar
    WIDTH = 8.0
    # Pixels between the bar and the window edge.
    INSET = 3.0
    # The thumb never gets shorter than this, so it stays easy to grab.
    MIN_THUMB = 24.0

    # The window area the page scrolls in.
    attr_reader :area #: Rect

    # @rbs @page_height: Float
    # @rbs @offset: Float

    #: (Float page_height, Rect area, Float offset) -> void
    def initialize(page_height, area, offset)
      @page_height = page_height
      @area = area
      @offset = offset
    end

    # Only a page taller than the window has anything to scroll.
    #: () -> bool
    def needed?
      @page_height > @area.height
    end

    #: () -> Rect
    def track
      Rect.new(@area.left + @area.width - WIDTH - INSET, @area.top, WIDTH, @area.height)
    end

    #: () -> Rect
    def thumb
      Rect.new(track.left, @area.top + (@offset / range * travel), WIDTH, thumb_height)
    end

    # The offset that puts the thumb's top at `thumb_top`, kept in range.
    #: (Float thumb_top) -> Float
    def offset_for(thumb_top)
      in_range((thumb_top - @area.top) / travel * range)
    end

    # Where the thumb is pressed on the track: -1 above it, 1 below it, 0
    # off the track.
    #: (Point point) -> Float
    def side_of(point)
      return 0.0 unless track.contains?(point)

      point.top < thumb.top ? -1.0 : 1.0
    end

    # The same bar, for the page scrolled to `offset`.
    #: (Float offset) -> Scrollbar
    def moved_to(offset)
      Scrollbar.new(@page_height, @area, offset)
    end

    # Into the overlay, which does not scroll.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      return unless needed?

      overlay.add(Box.new(track, Theme::Surface::SCROLL_TRACK))
      overlay.add(Box.new(thumb, Theme::Surface::SCROLL_THUMB))
    end

    # How far the page can scroll.
    #: () -> Float
    def range
      @page_height - @area.height
    end

    # The offset kept between the top and the end of the page. Not written
    # with `clamp`: that name pulls in Spinel's widening Comparable builtins
    # (docs/spinel-notes.md).
    #: (Float offset) -> Float
    def in_range(offset)
      return 0.0 if offset < 0.0 || range < 0.0

      [offset, range].min
    end

    private

    #: () -> Float
    def thumb_height
      window = @area.height
      [window * window / @page_height, MIN_THUMB].max
    end

    # How far the thumb can move along the track.
    #: () -> Float
    def travel
      @area.height - thumb_height
    end
  end
end
