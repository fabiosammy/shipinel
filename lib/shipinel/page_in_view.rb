# frozen_string_literal: true

# A laid-out page and how the window shows it: where the keyboard focus
# goes on Tab, where the window scrolls to show it, and its ring.

require_relative "draw_list"
require_relative "focus_steps"
require_relative "geometry"
require_relative "scroll_spot"

module Shipinel
  # A laid-out page and how the window shows it, for finding the
  # checkboxes the focus goes to, by their place in its draw list (page
  # order).
  class PageInView
    attr_reader :content #: DrawList
    attr_reader :view #: Viewport

    #: (DrawList content, Viewport view) -> void
    def initialize(content, view)
      @content = content
      @view = view
    end

    # The task line Tab (`step` 1) or Shift+Tab (-1) goes to from `line`
    # (-1: from just before the first checkbox in view), round the ends;
    # `line` itself for no step, -1 when the page has no checkbox.
    #: (Integer line, Integer step) -> Integer
    def line_after(line, step)
      return line if step.zero? || @content.empty?

      start = FocusSteps.position_of_line(@content, line)
      next_line(start.negative? ? first_in_view - 1 : start, step)
    end

    # Where the window goes to show the checkbox of task `line` when it
    # does not: that checkbox a third of the way down. ScrollSpot.none
    # when it is in view, or not on the page.
    #: (Integer line) -> ScrollSpot
    def aim_at(line)
      position = FocusSteps.position_of_line(@content, line)
      position.negative? ? ScrollSpot.none : aim_box(@content.at(position).rect)
    end

    # Where the window goes to show `box` (a page position): none when it
    # already does, else `box` a third of the way down.
    #: (Rect box) -> ScrollSpot
    def aim_box(box)
      @view.holds?(box) ? ScrollSpot.none : ScrollSpot.new("", 0.0, [box.top - (@view.height / 3), 0.0].max)
    end

    # A ring around the checkbox of task `line`, into `overlay` (window
    # positions), while all of it is in view.
    #: (DrawList overlay, Integer line) -> void
    def ring_at(overlay, line)
      position = FocusSteps.position_of_line(@content, line)
      return if position.negative?

      box = @content.at(position).rect
      FocusSteps.ring(overlay, box.up(@view.shift)) if @view.holds?(box)
      nil
    end

    private

    # The first checkbox at or below the window's top; the list's end when
    # there is none.
    #: () -> Integer
    def first_in_view
      top = @view.offset
      position = 0
      position += 1 while position < @content.size && !FocusSteps.box_below?(@content.at(position), top)
      position
    end

    # The line of the first checkbox after `start` going `step`, round the
    # ends (`start` itself last).
    #: (Integer start, Integer step) -> Integer
    def next_line(start, step)
      position = start + step
      stop = start + (step * @content.size)
      position += step while position != stop && !checkbox_at?(position)
      line_at(position)
    end

    #: (Integer position) -> bool
    def checkbox_at?(position)
      line_at(position) >= 0
    end

    # The task line of the checkbox at `position`, counted round the list
    # (so -1 is its last command); -1 when it is not a checkbox.
    #: (Integer position) -> Integer
    def line_at(position)
      size = @content.size
      FocusSteps.line_of(@content.at(((position % size) + size) % size))
    end
  end
end
