# frozen_string_literal: true

# Whether the user is busy with the window: scrolling, clicking, dragging
# or moving the pointer over it. Busy frames, and half a second of them
# after the last input, are drawn 60 times a second. Otherwise a frame is
# only drawn when the page changed or the window system asks for it, and
# an idle frame sleeps until input arrives (ui_skip_frame).

require_relative "geometry"
require_relative "mouse_state"

module Shipinel
  # See the file comment.
  class Activity
    # Frames after the last input that are still drawn: half a second.
    LINGER = 30

    # @rbs @at: Point
    # @rbs @quiet: Integer

    #: () -> void
    def initialize
      @at = Point.new(-1.0, -1.0)
      @quiet = LINGER
    end

    # Called once a frame with that frame's mouse.
    #: (MouseState mouse) -> void
    def note(mouse)
      at = mouse.at
      busy = mouse.input? || !at.same_as?(@at)
      @quiet = busy ? 0 : @quiet + 1
      @at = at
    end

    # Busy frames are always drawn.
    #: () -> bool
    def due?
      @quiet < LINGER
    end
  end
end
