# frozen_string_literal: true

# The keys Shipinel answers to, and what was pressed in one frame. The C
# shim reports, for the watched keys in order, which went down (or repeated
# while held) this frame, as one bit each; this file gives the bits their
# meaning. Codes are raylib's (raylib.h KeyboardKey, docs/raylib-notes.md).

require_relative "scrollbar"

module Shipinel
  # See the file comment.
  module Keyboard
    # A line down or up.
    module Lines
      J = 74
      DOWN = 264
      K = 75
      UP = 265
    end

    # A window down or up, and the two ends.
    module Jumps
      PAGE_DOWN = 267
      PAGE_UP = 266
      HOME = 268
      END_KEY = 269
    end

    # Text size. "=" is the key that types "+" with Shift; both work with
    # or without Ctrl.
    module Zoom
      EQUAL = 61
      KEYPAD_PLUS = 334
      MINUS = 45
      KEYPAD_MINUS = 333
      ZERO = 48
    end

    # Hides or shows the progress header.
    HEADER = 72
    # Undoes the last tick.
    UNDO = 85

    # With Control: copy the selection (C), select everything (A).
    module Selecting
      C = 67
      A = 65
    end

    # Bit n of a KeyPress is the n-th key here.
    #: () -> Array[Integer]
    def self.watched
      [Lines::J, Lines::DOWN, Lines::K, Lines::UP, Jumps::PAGE_DOWN, Jumps::PAGE_UP, Jumps::HOME, Jumps::END_KEY,
       Zoom::EQUAL, Zoom::KEYPAD_PLUS, Zoom::MINUS, Zoom::KEYPAD_MINUS, Zoom::ZERO, HEADER, UNDO,
       Selecting::C, Selecting::A]
    end
  end

  # What the watched keys did in one frame (Keyboard.watched, one bit each).
  class KeyPress
    # Pixels per line key, as per mouse wheel notch.
    LINE = 48.0

    # Bits of the keys that move the page.
    module Moves
      LINE_DOWN = 0b11
      LINE_UP = 0b1100
      PAGE_DOWN = 0b1_0000
      PAGE_UP = 0b10_0000
    end

    # Bits of the keys that jump to an end or change the view.
    module Changes
      TOP = 0b100_0000
      BOTTOM = 0b1000_0000
      ZOOM_IN = 0b11_0000_0000
      ZOOM_OUT = 0b1100_0000_0000
      ZOOM_RESET = 0b1_0000_0000_0000
    end

    HEADER = 0b10_0000_0000_0000
    UNDO = 0b100_0000_0000_0000

    # Bits of the selection keys, and of Control.
    module Selecting
      C = 0b1000_0000_0000_0000
      A = 0b1_0000_0000_0000_0000
      # Not a watched key: Screen sets it while Control is held, so it says
      # nothing on its own (`pressed?` leaves it out).
      CONTROL = 0x4000_0000
    end

    # @rbs @bits: Integer

    #: (Integer bits) -> void
    def initialize(bits)
      @bits = bits
    end

    # A watched key went down (Control alone does not count).
    #: () -> bool
    def pressed?
      @bits.anybits?(~Selecting::CONTROL)
    end

    # Where these keys move a page scrolled to `offset`: a line (j, k, the
    # arrows), a window (Page Up, Page Down), or an end (Home and End win).
    #: (Float offset, Scrollbar bar) -> Float
    def scrolled(offset, bar)
      return 0.0 if on?(Changes::TOP)
      return bar.range if on?(Changes::BOTTOM)

      offset + (step(Moves::LINE_DOWN, Moves::LINE_UP) * LINE) +
        (step(Moves::PAGE_DOWN, Moves::PAGE_UP) * bar.track.height)
    end

    # 1 to make the text bigger (+), -1 smaller (-).
    #: () -> Integer
    def zoom_step
      step(Changes::ZOOM_IN, Changes::ZOOM_OUT)
    end

    # 0: back to the --font-size the window started with.
    #: () -> bool
    def zoom_reset?
      on?(Changes::ZOOM_RESET)
    end

    # h: hide or show the progress header.
    #: () -> bool
    def header?
      on?(HEADER)
    end

    # u: undo the last tick.
    #: () -> bool
    def undo?
      on?(UNDO)
    end

    # Ctrl+C: copy the selection.
    #: () -> bool
    def copy?
      on?(Selecting::CONTROL) && on?(Selecting::C)
    end

    # Ctrl+A: select the whole page.
    #: () -> bool
    def select_all?
      on?(Selecting::CONTROL) && on?(Selecting::A)
    end

    private

    #: (Integer mask) -> bool
    def on?(mask)
      @bits.anybits?(mask)
    end

    #: (Integer forward, Integer back) -> Integer
    def step(forward, back)
      (on?(forward) ? 1 : 0) - (on?(back) ? 1 : 0)
    end
  end
end
