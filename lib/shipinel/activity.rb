# frozen_string_literal: true

# Whether the user is busy with the window: scrolling, clicking, dragging,
# pressing a key or moving the pointer over it. Busy frames, and half a second of them
# after the last input, are drawn 60 times a second. Otherwise a frame is
# only drawn when the page changed or the window system asks for it, and
# an idle frame sleeps until input arrives (ui_skip_frame).

require_relative "geometry"
require_relative "input"

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

    # Called once a frame with that frame's input.
    #: (Input input) -> void
    def note(input)
      at = input.at
      busy = input.active? || !at.same_as?(@at)
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
