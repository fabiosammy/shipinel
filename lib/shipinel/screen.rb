# frozen_string_literal: true

# The window, as the rest of the app sees it: Ruby names and value objects
# over the raw FFI calls in UI. App takes a Screen, so its tests run under
# CRuby with a fake one. UI itself is required only by bin/shipinel.rb.
# Stateless on purpose: the window's state lives in the C shim (.reek.yml).
# The shim's yes/no answers are C ints, which is exactly what the FFI's
# :bool is, so they arrive here as true/false.

require_relative "font_shim"
require_relative "geometry"
require_relative "mouse_state"
require_relative "theme"

module Shipinel
  # See the file comment.
  class Screen
    #: (Integer width, Integer height, String title) -> void
    def open(width, height, title)
      UI.ui_open_window(width, height, title)
    end

    # Whether `open` got a window (and an OpenGL context).
    #: () -> bool
    def ready?
      UI.ui_window_ready
    end

    #: () -> bool
    def closing?
      UI.ui_window_should_close
    end

    #: () -> void
    def close
      UI.ui_close_window
    end

    # The window's drawing area, which the user may resize at any time.
    #: () -> Rect
    def area
      Rect.new(0.0, 0.0, UI.ui_screen_width.to_f, UI.ui_screen_height.to_f)
    end

    # The fonts this window draws with.
    #: () -> FontShim
    def font_shim
      FontShim.new
    end

    #: (Integer background) -> void
    def begin_frame(background)
      UI.ui_begin_frame(background)
    end

    # Waits until the frame is due at this rate, then shows it.
    #: (Integer frames_per_second) -> void
    def end_frame(frames_per_second)
      UI.ui_set_frame_rate(frames_per_second)
      UI.ui_end_frame
    end

    #: (String text, Point at, TextStyle style) -> void
    def draw_text(text, at, style)
      UI.ui_draw_text(style.font_slot, text, at.left, at.top, style.size, style.color)
    end

    #: (Rect rect, Integer color) -> void
    def draw_rect(rect, color)
      UI.ui_draw_rect(rect.left, rect.top, rect.width, rect.height, color)
    end

    # The mouse this frame: where it is, its left button, and its wheel.
    #: () -> MouseState
    def mouse
      MouseState.new(Point.new(UI.ui_mouse_x.to_f, UI.ui_mouse_y.to_f), UI.ui_mouse_buttons, UI.ui_wheel_move)
    end

    #: (Integer border, Integer hover, Integer check) -> void
    def style_checkboxes(border, hover, check)
      UI.ui_style_checkbox(border, hover, check)
    end

    # A square checkbox filling `rect`. Clicks are read with pointer_on;
    # the file, not the box, holds the state.
    #: (Rect rect, bool checked) -> void
    def draw_checkbox(rect, checked)
      UI.ui_draw_checkbox(rect.left, rect.top, rect.width, checked)
    end

    # Where the mouse is relative to `rect`: :away, :over, or :clicked (the
    # left button was released over it this frame).
    #: (Rect rect) -> Symbol
    def pointer_on(rect)
      case UI.ui_pointer_on(rect.left, rect.top, rect.width, rect.height)
      when 2 then :clicked
      when 1 then :over
      else :away
      end
    end

    # The pointing hand while the mouse is over something clickable.
    #: (bool hand) -> void
    def use_hand_cursor(hand)
      UI.ui_set_hand_cursor(hand)
    end
  end
end
