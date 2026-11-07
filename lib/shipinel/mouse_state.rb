# frozen_string_literal: true

# The mouse in one frame: where it is, its left button, and how far its
# wheel moved (positive scrolls toward the top).

require_relative "geometry"

module Shipinel
  # See the file comment.
  class MouseState
    # The C shim's button bits (ext/ui_shim.h).
    DOWN = 1
    PRESSED = 2

    attr_reader :at #: Point
    attr_reader :wheel #: Float

    # @rbs @buttons: Integer

    #: (Point at, Integer buttons, Float wheel) -> void
    def initialize(at, buttons, wheel)
      @at = at
      @buttons = buttons
      @wheel = wheel
    end

    # The left button is held.
    #: () -> bool
    def down?
      @buttons.anybits?(DOWN)
    end

    # The left button went down this frame.
    #: () -> bool
    def pressed?
      @buttons.anybits?(PRESSED)
    end
  end
end
