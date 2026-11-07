# frozen_string_literal: true

# The scroll position of the page, moved by the mouse wheel and the
# scrollbar (drag the thumb; press the track above or below it to move a
# window's height). It survives reloads: after the file changes, the same
# offset is kept, only clamped to the new page height.

require_relative "activity"
require_relative "mouse_state"
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

    #: () -> void
    def initialize
      @offset = 0.0
      @grab = NOT_DRAGGING
      @activity = Activity.new
    end

    # Called once a frame, drawn or not, with that frame's mouse.
    #: (MouseState mouse) -> void
    def note(mouse)
      @activity.note(mouse)
    end

    # Whether this frame is drawn even if the page did not change: while
    # the user scrolls or points (Activity).
    #: () -> bool
    def due?
      @activity.due?
    end

    # Keeps the page between its top and where its end reaches the bottom
    # of the window. A page shorter than the window never moves. Returns
    # the new offset.
    #: (MouseState mouse, Scrollbar bar) -> Float
    def apply(mouse, bar)
      @offset = bar.in_range(@offset - (mouse.wheel * STEP))
      drag(mouse, bar) if bar.needed?
      @offset
    end

    private

    #: (MouseState mouse, Scrollbar bar) -> void
    def drag(mouse, bar)
      at = mouse.at
      grab(at, bar) if mouse.pressed?
      @grab = NOT_DRAGGING unless mouse.down?
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
