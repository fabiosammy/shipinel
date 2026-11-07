# frozen_string_literal: true

# Whether the user is busy with the window: scrolling, clicking, dragging
# or moving the pointer over it. Input is read 60 times a second, so even a
# quick click is seen, but a frame is only drawn while the user is busy
# (and half a second after), when the page changed, or every 2 s in case
# the window system lost the picture (an X11 desktop without a compositor
# does not keep it). Idle frames cost a sleep and an input poll.

require_relative "geometry"
require_relative "mouse_state"

module Shipinel
  # See the file comment.
  class Activity
    # Frames after the last input that are still drawn: half a second.
    LINGER = 30
    # Idle frames between redraws of an unchanged page: 2 s.
    REFRESH = 120

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

    # How this frame runs; `changed` says whether the page changed since
    # the last frame drawn.
    #: (bool changed) -> Pace
    def pace(changed)
      Pace.new(due?, changed)
    end

    private

    # Busy frames are always drawn; idle ones every REFRESH frames.
    #: () -> bool
    def due?
      @quiet < LINGER || ((@quiet - LINGER) % REFRESH).zero?
    end
  end

  # Whether a frame is drawn at all: an unchanged idle page is left on
  # screen as it is.
  class Pace
    # @rbs @due: bool
    # @rbs @changed: bool

    # `due`: busy, or time for the idle refresh; `changed`: the page is not
    # the one on screen.
    #: (bool due, bool changed) -> void
    def initialize(due, changed)
      @due = due
      @changed = changed
    end

    #: () -> bool
    def redraw?
      @due || @changed
    end
  end
end
