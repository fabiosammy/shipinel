# frozen_string_literal: true

# Whether the user is busy with the window: scrolling, clicking, dragging
# or moving the pointer over it. Busy frames run at 60 a second, so the
# page follows the hand; half a second after the last input the window
# drops back to 10, which keeps it light while idle.

require_relative "geometry"
require_relative "mouse_state"

module Shipinel
  # See the file comment.
  class Activity
    BUSY_RATE = 60
    IDLE_RATE = 10
    # Busy frames after the last input: half a second at BUSY_RATE.
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
      @quiet = busy ? 0 : [@quiet + 1, LINGER].min
      @at = at
    end

    #: () -> Integer
    def frame_rate
      @quiet < LINGER ? BUSY_RATE : IDLE_RATE
    end
  end
end
