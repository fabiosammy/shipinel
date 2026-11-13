# frozen_string_literal: true

# The keys Shipinel answers to, and what was pressed in one frame. The C
# shim reports, for the watched keys in order, which went down (or repeated
# while held) this frame, as one bit each; this file gives the bits their
# meaning, and keeps what was typed for the find bar. Codes are raylib's
# (raylib.h KeyboardKey, docs/raylib-notes.md).

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
    # Opens or closes the outline (the list of sections to jump to).
    OUTLINE = 71

    # With Control: copy the selection (C), select everything (A).
    module Selecting
      C = 67
      A = 65
    end

    # Ctrl+F opens the find bar; Enter goes to the next match (with Shift,
    # the previous), Backspace takes back a character, Escape closes it.
    module Finding
      F = 70
      ESCAPE = 256
      ENTER = 257
      KEYPAD_ENTER = 335
      BACKSPACE = 259
    end

    # Tab moves the keyboard focus to the next checkbox (with Shift, the
    # previous one) and Space ticks it; Escape clears it.
    module Focusing
      TAB = 258
      SPACE = 32
    end

    # Bit n of a KeyPress is the n-th key here.
    #: () -> Array[Integer]
    def self.watched
      [Lines::J, Lines::DOWN, Lines::K, Lines::UP, Jumps::PAGE_DOWN, Jumps::PAGE_UP, Jumps::HOME, Jumps::END_KEY,
       Zoom::EQUAL, Zoom::KEYPAD_PLUS, Zoom::MINUS, Zoom::KEYPAD_MINUS, Zoom::ZERO, HEADER, UNDO,
       Selecting::C, Selecting::A, Finding::F, Finding::ESCAPE, Finding::ENTER, Finding::KEYPAD_ENTER,
       Finding::BACKSPACE, Focusing::TAB, Focusing::SPACE, OUTLINE]
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
      # j, k, the zoom keys, h, u, Tab, Space and g: while the find bar is
      # open they are typed (or ignored), not obeyed (`while_finding`).
      TYPED = 0x1C0_7F05
    end

    # What was typed this frame (for the find bar), "" for nothing.
    attr_reader :typed #: String

    # @rbs @bits: Integer

    #: (Integer bits, String typed) -> void
    def initialize(bits, typed)
      @bits = bits
      @typed = typed
    end

    # A watched key went down or something was typed (Control or Shift
    # alone does not count).
    #: () -> bool
    def pressed?
      @bits.anybits?(~(Selecting::CONTROL | FindKeys::SHIFT)) || !@typed.empty?
    end

    # The same keys with the letter commands left out, while the find bar
    # takes the letters.
    #: () -> KeyPress
    def while_finding
      KeyPress.new(@bits & ~Selecting::TYPED, @typed)
    end

    # What these keys do to the find bar.
    #: () -> FindKeys
    def for_finding
      FindKeys.new(@bits, @typed)
    end

    # What these keys do to the keyboard focus.
    #: () -> FocusKeys
    def for_focus
      FocusKeys.new(@bits)
    end

    # What these keys do to the outline.
    #: () -> OutlineKeys
    def for_outline
      OutlineKeys.new(@bits)
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

  # The find bar's keys in one frame (Keyboard::Finding), and what was typed.
  class FindKeys
    OPEN = 0b10_0000_0000_0000_0000
    CLOSE = 0b100_0000_0000_0000_0000
    ENTER = 0b1_1000_0000_0000_0000_0000
    ERASE = 0b10_0000_0000_0000_0000_0000
    # Not a watched key: Screen sets it while Shift is held.
    SHIFT = 0x2000_0000

    attr_reader :typed #: String

    # @rbs @bits: Integer

    #: (Integer bits, String typed) -> void
    def initialize(bits, typed)
      @bits = bits
      @typed = typed
    end

    # Ctrl+F.
    #: () -> bool
    def open?
      @bits.allbits?(OPEN | KeyPress::Selecting::CONTROL)
    end

    # Escape.
    #: () -> bool
    def close?
      @bits.anybits?(CLOSE)
    end

    # Backspace.
    #: () -> bool
    def erase?
      @bits.anybits?(ERASE)
    end

    # 1: the next match (Enter), -1: the previous one (Shift+Enter), 0.
    #: () -> Integer
    def step
      return 0 unless @bits.anybits?(ENTER)

      @bits.anybits?(SHIFT) ? -1 : 1
    end
  end

  # The keyboard focus's keys in one frame (Keyboard::Focusing).
  class FocusKeys
    NEXT = 0x40_0000
    TICK = 0x80_0000

    # @rbs @bits: Integer

    #: (Integer bits) -> void
    def initialize(bits)
      @bits = bits
    end

    # 1: the next checkbox (Tab), -1: the previous one (Shift+Tab), 0.
    #: () -> Integer
    def step
      return 0 unless @bits.anybits?(NEXT)

      @bits.anybits?(FindKeys::SHIFT) ? -1 : 1
    end

    # Space.
    #: () -> bool
    def tick?
      @bits.anybits?(TICK)
    end

    # Escape.
    #: () -> bool
    def clear?
      @bits.anybits?(FindKeys::CLOSE)
    end

    # The focus these keys leave, from task `line` on `page`: Escape lets
    # go; Tab moves; Space presses the checkbox it ends on.
    #: (Integer line, PageInView page) -> Focus
    def focus_after(line, page)
      return Focus.none if clear?

      moved = page.line_after(line, step)
      Focus.new(moved, tick? && moved >= 0)
    end
  end

  # The outline's keys in one frame: g opens or closes it, the line keys
  # (j, k, the arrows) move its selection, Enter jumps, Escape closes.
  class OutlineKeys
    TOGGLE = 0x100_0000

    # @rbs @bits: Integer

    #: (Integer bits) -> void
    def initialize(bits)
      @bits = bits
    end

    #: () -> bool
    def toggle?
      @bits.anybits?(TOGGLE)
    end

    #: () -> bool
    def close?
      @bits.anybits?(FindKeys::CLOSE)
    end

    #: () -> bool
    def jump?
      @bits.anybits?(FindKeys::ENTER)
    end

    # 1: the next section (j, Down), -1: the previous one (k, Up), 0.
    #: () -> Integer
    def step
      (@bits.anybits?(KeyPress::Moves::LINE_DOWN) ? 1 : 0) - (@bits.anybits?(KeyPress::Moves::LINE_UP) ? 1 : 0)
    end
  end
end
