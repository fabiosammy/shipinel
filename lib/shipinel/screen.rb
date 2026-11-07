# frozen_string_literal: true

# The window, as the rest of the app sees it: Ruby names and value objects
# over the raw FFI calls in UI. App takes a Screen, so its tests run under
# CRuby with a fake one. UI itself is required only by bin/shipinel.rb.
# Stateless on purpose: the window's state lives in the C shim (.reek.yml).
# The shim's yes/no answers are C ints, which is exactly what the FFI's
# :bool is, so they arrive here as true/false.

require_relative "geometry"
require_relative "text_measure"
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

    #: (Integer background) -> void
    def begin_frame(background)
      UI.ui_begin_frame(background)
    end

    #: () -> void
    def end_frame
      UI.ui_end_frame
    end

    #: (Integer font_slot, String path, Integer pixel_size) -> void
    def load_font(font_slot, path, pixel_size)
      UI.ui_load_font(font_slot, path, pixel_size)
    end

    # False when the font could not be loaded; the slot then has raylib's
    # built-in font, which lacks accented letters.
    #: (Integer font_slot) -> bool
    def font_loaded?(font_slot)
      UI.ui_font_loaded(font_slot)
    end

    # Measures text in the fonts this window loaded.
    #: () -> TextMeasure
    def text_measure
      TextMeasure.new
    end

    #: (String text, Point at, TextStyle style) -> void
    def draw_text(text, at, style)
      UI.ui_draw_text(style.font_slot, text, at.left, at.top, style.size, style.color)
    end

    #: (Rect rect, Integer color) -> void
    def draw_rect(rect, color)
      UI.ui_draw_rect(rect.left, rect.top, rect.width, rect.height, color)
    end

    # How far the wheel moved this frame; positive scrolls toward the top.
    #: () -> Float
    def wheel_move
      UI.ui_wheel_move
    end

    #: (Integer border, Integer hover, Integer check) -> void
    def style_checkboxes(border, hover, check)
      UI.ui_style_checkbox(border, hover, check)
    end

    # Draws a square checkbox filling `rect`; true on the frame it was
    # clicked. The file, not the box, holds the state, so the caller toggles
    # the task and the next layout shows the result.
    #: (Rect rect, bool checked) -> bool
    def checkbox_clicked?(rect, checked)
      UI.ui_checkbox(rect.left, rect.top, rect.width, checked)
    end
  end
end
