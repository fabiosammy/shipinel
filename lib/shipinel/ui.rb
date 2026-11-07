# frozen_string_literal: true

# Spinel FFI declarations for ext/ui_shim.c. Spinel-only: CRuby has no
# ffi_func, so only bin/shipinel.rb requires this file; the rest of the app
# talks to Screen. Types follow ext/ui_shim.h exactly (yes/no as :int).

module Shipinel
  # See the file comment.
  module UI
    ffi_lib "raylib"

    ffi_func :ui_open_window, %i[int int str], :void
    ffi_func :ui_window_ready, [], :int
    ffi_func :ui_window_should_close, [], :int
    ffi_func :ui_close_window, [], :void
    ffi_func :ui_screen_width, [], :int
    ffi_func :ui_screen_height, [], :int
    ffi_func :ui_begin_frame, %i[uint32], :void
    ffi_func :ui_end_frame, [], :void
    ffi_func :ui_load_font, %i[int str int], :void
    ffi_func :ui_font_loaded, %i[int], :int
    ffi_func :ui_text_width, %i[int str float], :float
    ffi_func :ui_draw_text, %i[int str float float float uint32], :void
  end
end
