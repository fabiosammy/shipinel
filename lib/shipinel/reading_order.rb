# frozen_string_literal: true

# Reading order on a laid-out page: top to bottom, then left to right. A
# selection runs from one point to another in this order.

require_relative "geometry"

module Shipinel
  # See the file comment.
  module ReadingOrder
    # Where `point` falls against the piece of text in `rect`: -1 before
    # its middle (above its line, or left of its middle on the line), 1
    # after it.
    #: (Point point, Rect rect) -> Integer
    def self.side(point, rect)
      line = ReadingOrder.line_side(point.top, rect)
      line.zero? ? ReadingOrder.side_on_line(point, rect) : line
    end

    # -1 above the piece's line, 1 below it, 0 on it.
    #: (Float top, Rect rect) -> Integer
    def self.line_side(top, rect)
      line_top = rect.top
      return -1 if top < line_top

      top >= line_top + rect.height ? 1 : 0
    end

    # On the piece's line: before or after its middle.
    #: (Point point, Rect rect) -> Integer
    def self.side_on_line(point, rect)
      point.left <= rect.left + (rect.width / 2) ? -1 : 1
    end

    #: (Point one, Point other) -> bool
    def self.before?(one, other)
      top = one.top
      other_top = other.top
      top < other_top || (top == other_top && one.left < other.left)
    end
  end
end
