# frozen_string_literal: true

# The window, as the rest of the app sees it: Ruby names and value objects
# over the raw FFI calls in UI. App takes a Screen, so its tests run under
# CRuby with a fake one. UI itself is required only by bin/shipinel.rb.
# Stateless on purpose: the window's state lives in the C shim (.reek.yml).

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
      UI.ui_window_ready == 1
    end

    #: () -> bool
    def closing?
      UI.ui_window_should_close == 1
    end

    #: () -> void
    def close
      UI.ui_close_window
    end

    #: () -> Integer
    def width
      UI.ui_screen_width
    end

    #: () -> Integer
    def height
      UI.ui_screen_height
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
      UI.ui_font_loaded(font_slot) == 1
    end

    #: (String text, TextStyle style) -> Float
    def text_width(text, style)
      UI.ui_text_width(style.font_slot, text, style.size)
    end

    #: (String text, Point at, TextStyle style) -> void
    def draw_text(text, at, style)
      UI.ui_draw_text(style.font_slot, text, at.left, at.top, style.size, style.color)
    end
  end
end
