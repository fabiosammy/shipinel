# frozen_string_literal: true

# Reads this frame's keyboard from the C shim: the watched keys as bits,
# Control and Shift as their own bits, and the characters typed.

require_relative "keyboard"

module Shipinel
  # This frame's watched keys, with Control and Shift as their own bits,
  # and what was typed.
  module KeyReader
    #: () -> KeyPress
    def self.read
      keys = Keyboard.watched
      KeyPress.new(UI.ui_keys_pressed(keys, keys.size) | modifiers, typed)
    end

    #: () -> Integer
    def self.modifiers
      (UI.ui_control_down ? KeyPress::Selecting::CONTROL : 0) | (UI.ui_shift_down ? FindKeys::SHIFT : 0)
    end

    # The characters typed since the last frame, in order.
    #: () -> String
    def self.typed
      text = +""
      while (codepoint = UI.ui_char_pressed).positive?
        text << codepoint
      end
      text
    end
  end
end
