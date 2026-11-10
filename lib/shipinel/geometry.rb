# frozen_string_literal: true

# Positions and rectangles in window pixels, measured from the top-left
# corner of the page. `Rect#up` turns a page position into a window position
# for the current scroll offset.

module Shipinel
  # A position, e.g. where a run of text starts.
  class Point
    attr_reader :left #: Float
    attr_reader :top #: Float

    #: (Float left, Float top) -> void
    def initialize(left, top)
      @left = left
      @top = top
    end

    # The same point `distance` further down (a window point on the page).
    #: (Float distance) -> Point
    def down(distance)
      Point.new(@left, @top + distance)
    end

    #: (Point other) -> bool
    def same_as?(other)
      @left == other.left && @top == other.top
    end
  end

  # A rectangle: a code background, a rule, a checkbox.
  class Rect
    OUTSIDE = -1.0

    attr_reader :left #: Float
    attr_reader :top #: Float
    attr_reader :width #: Float
    attr_reader :height #: Float

    #: (Float left, Float top, Float width, Float height) -> void
    def initialize(left, top, width, height)
      @left = left
      @top = top
      @width = width
      @height = height
    end

    #: (Float distance) -> Rect
    def up(distance)
      Rect.new(@left, @top - distance, @width, @height)
    end

    # The left `share` (0.0 to 1.0) of this rectangle: a filled bar.
    #: (Float share) -> Rect
    def left_part(share)
      Rect.new(@left, @top, @width * share, @height)
    end

    # A tick `width` wide across this rectangle at `share` of its width,
    # reaching `reach` above and below it.
    #: (Float share, Float width, Float reach) -> Rect
    def tick_at(share, width, reach)
      Rect.new(@left + (@width * share) - (width / 2), @top - reach, width, @height + (reach * 2))
    end

    # What is left below the first `height` pixels.
    #: (Float height) -> Rect
    def below(height)
      Rect.new(@left, @top + height, @width, @height - height)
    end

    #: () -> Point
    def corner
      Point.new(@left, @top)
    end

    #: (Point point) -> bool
    def contains?(point)
      left = point.left
      top = point.top
      left >= @left && left < @left + @width && top >= @top && top < @top + @height
    end

    # How far below the top edge `point` is, or OUTSIDE when it is not in
    # the rectangle.
    #: (Point point) -> Float
    def depth_of(point)
      contains?(point) ? point.top - @top : OUTSIDE
    end

    # The same rectangle with its left edge moved right by `by`.
    #: (Float by) -> Rect
    def indented(by)
      Rect.new(@left + by, @top, @width - by, @height)
    end

    # A one-pixel line under text drawn in `band(band_height)` at `text_size`:
    # just under the baseline.
    #: (Float band_height, Float text_size) -> Rect
    def underline(band_height, text_size)
      Rect.new(@left, band(band_height).top + (text_size * 0.95), @width, 1.0)
    end

    # A one-pixel line through the middle of lowercase letters of text drawn
    # in `band(band_height)` at `text_size`.
    #: (Float band_height, Float text_size) -> Rect
    def strike(band_height, text_size)
      Rect.new(@left, band(band_height).top + (text_size * 0.6), @width, 1.0)
    end

    # A strip of this rectangle, `height` tall, centered vertically: where
    # smaller text sits on a line.
    #: (Float height) -> Rect
    def band(height)
      Rect.new(@left, @top + ((@height - height) / 2), @width, height)
    end
  end

  # How the page sits in the window: scrolled to `offset` inside `area`,
  # the part of the window below the progress header.
  class Viewport
    # How far up the page is drawn: the offset, less the header's room.
    attr_reader :shift #: Float
    attr_reader :top #: Float

    # @rbs @bottom: Float

    #: (Float offset, Rect area) -> void
    def initialize(offset, area)
      top = area.top
      @shift = offset - top
      @top = top
      @bottom = top + area.height
    end

    # The same page position under the same header: frames that agree
    # draw the page in the same place.
    #: (Viewport other) -> bool
    def same_as?(other)
      @shift == other.shift && @top == other.top
    end

    # Whether any of `rect`, in window position, is inside the area.
    #: (Rect rect) -> bool
    def shows?(rect)
      top = rect.top
      top < @bottom && top + rect.height > @top
    end
  end
end
