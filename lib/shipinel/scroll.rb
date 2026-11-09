# frozen_string_literal: true

# The scroll position of the page, moved by the mouse wheel, the keys (a
# line with j, k and the arrows, a window with Page Up and Page Down, to
# either end with Home and End) and the scrollbar (drag the thumb; press
# the track above or below it to move a window's height). It survives reloads: after the file changes, the same
# offset is kept, only clamped to the new page height.

require_relative "activity"
require_relative "input"
require_relative "scroll_spot"
require_relative "draw_list"
require_relative "scrollbar"

module Shipinel
  # See the file comment.
  class Scroll
    # Pixels moved per mouse wheel notch.
    STEP = 48.0
    NOT_DRAGGING = -1.0

    attr_reader :offset #: Float

    # How far below the thumb's top it was grabbed, while it is dragged.
    # @rbs @grab: Float
    # @rbs @activity: Activity
    # A place to go to once the page is laid out (ScrollSpot.none: none).
    # @rbs @aim: ScrollSpot

    #: () -> void
    def initialize
      @offset = 0.0
      @grab = NOT_DRAGGING
      @activity = Activity.new
      @aim = ScrollSpot.none
    end

    # Goes to `spot` on the next frame that lays the page out: where the
    # window was last time, or the same section after a zoom.
    #: (ScrollSpot spot) -> void
    def aim(spot)
      @aim = spot
      nil
    end

    # Called once a frame, drawn or not, with that frame's input.
    #: (Input input) -> void
    def note(input)
      @activity.note(input)
    end

    # Whether this frame is drawn even if the page did not change: while
    # the user scrolls or points (Activity).
    #: () -> bool
    def due?
      @activity.due?
    end

    # Applies this frame's input to `content` shown in `area`; returns the
    # bar where the page ended up.
    #: (Input input, DrawList content, Rect area) -> Scrollbar
    def bar_for(input, content, area)
      bar = Scrollbar.new(content.height, area, @offset)
      bar.moved_to(apply(input, bar, content.anchors))
    end

    # Keeps the page between its top and where its end reaches the bottom
    # of the window. A page shorter than the window never moves. Returns
    # the new offset.
    #: (Input input, Scrollbar bar, AnchorList anchors) -> Float
    def apply(input, bar, anchors)
      arrive(anchors)
      @offset = bar.in_range(input.keys.scrolled(@offset, bar) - (input.wheel * STEP))
      drag(input, bar) if bar.needed?
      @offset
    end

    private

    #: (AnchorList anchors) -> void
    def arrive(anchors)
      spot = @aim
      return unless spot.aimed?

      @offset = spot.offset_in(anchors)
      @aim = ScrollSpot.none
    end

    #: (Input input, Scrollbar bar) -> void
    def drag(input, bar)
      at = input.at
      grab(at, bar) if input.pressed?
      @grab = NOT_DRAGGING unless input.down?
      @offset = bar.offset_for(at.top - @grab) unless @grab.negative?
      nil
    end

    # A press on the thumb starts a drag; one on the track beside it pages.
    #: (Point at, Scrollbar bar) -> void
    def grab(at, bar)
      @grab = bar.thumb.depth_of(at)
      page(bar.side_of(at), bar) if @grab.negative?
      nil
    end

    # One window's height up (-1) or down (1); 0 stays.
    #: (Float direction, Scrollbar bar) -> void
    def page(direction, bar)
      @offset = bar.in_range(@offset + (direction * bar.track.height))
      nil
    end
  end
end
