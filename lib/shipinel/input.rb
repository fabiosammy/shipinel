# frozen_string_literal: true

# The user's input in one frame: where the mouse is, its left button, how
# far its wheel moved (positive scrolls toward the top), and which of the
# watched keys were pressed.

require_relative "geometry"
require_relative "keyboard"

module Shipinel
  # See the file comment.
  class Input
    # The C shim's button bits (ext/ui_shim.h).
    DOWN = 1
    PRESSED = 2

    attr_reader :at #: Point
    attr_reader :wheel #: Float
    attr_reader :keys #: KeyPress

    # @rbs @buttons: Integer

    #: (Point at, Integer buttons, Float wheel, KeyPress keys) -> void
    def initialize(at, buttons, wheel, keys)
      @at = at
      @buttons = buttons
      @wheel = wheel
      @keys = keys
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

    # The wheel turned, the button is held or pressed, or a key was pressed.
    #: () -> bool
    def active?
      !@wheel.zero? || @buttons.positive? || @keys.pressed?
    end
  end
end
