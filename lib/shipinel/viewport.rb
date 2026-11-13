# frozen_string_literal: true

# How the laid-out page sits in the window's page area (below the header),
# for drawing only what shows and scrolling to what must.

module Shipinel
  # How the page sits in the window: scrolled to `offset` inside `area`,
  # the part of the window below the progress header.
  class Viewport
    # How far up the page is drawn: the offset, less the header's room.
    attr_reader :shift #: Float
    attr_reader :top #: Float
    attr_reader :width #: Float
    # Where the area ends, in the window.
    attr_reader :bottom #: Float

    #: (Float offset, Rect area) -> void
    def initialize(offset, area)
      top = area.top
      @shift = offset - top
      @top = top
      @bottom = top + area.height
      @width = area.width
    end

    # The same page position under the same header: frames that agree
    # draw the page in the same place.
    #: (Viewport other) -> bool
    def same_as?(other)
      @shift == other.shift && @top == other.top
    end

    # Where the page is scrolled to: the page position at the area's top.
    #: () -> Float
    def offset
      @shift + @top
    end

    # The area itself, in the window.
    #: () -> Rect
    def area
      Rect.new(0.0, @top, @width, height)
    end

    # How tall the area is.
    #: () -> Float
    def height
      @bottom - @top
    end

    # Whether all of `rect`, a page position, is inside the area.
    #: (Rect rect) -> bool
    def holds?(rect)
      top = rect.top - @shift
      top >= @top && top + rect.height <= @bottom
    end

    # Whether any of `rect`, in window position, is inside the area.
    #: (Rect rect) -> bool
    def shows?(rect)
      top = rect.top
      top < @bottom && top + rect.height > @top
    end
  end
end
