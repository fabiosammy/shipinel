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
  end

  # A rectangle: a code background, a rule, a checkbox.
  class Rect
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

    #: () -> Point
    def corner
      Point.new(@left, @top)
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

    # A strip of this rectangle, `height` tall, centered vertically: where
    # smaller text sits on a line.
    #: (Float height) -> Rect
    def band(height)
      Rect.new(@left, @top + ((@height - height) / 2), @width, height)
    end
  end
end
