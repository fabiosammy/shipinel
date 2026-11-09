# frozen_string_literal: true

# Spinel FFI declarations for ext/ui_shim.c. Spinel-only: CRuby has no
# ffi_func, so only bin/shipinel.rb requires this file; the rest of the app
# talks to Screen. Types follow ext/ui_shim.h; its yes/no ints are :bool,
# which the FFI defines as a C int.

module Shipinel
  # See the file comment.
  module UI
    ffi_lib "raylib"
    # The shim calls GLFW directly to wait for input while idle.
    ffi_lib "glfw"
    # The tray icon talks to the session bus through sd-bus.
    ffi_lib "systemd"

    ffi_func :ui_open_window, %i[int int str], :void
    ffi_func :ui_window_ready, [], :bool
    ffi_func :ui_window_should_close, [], :bool
    ffi_func :ui_close_window, [], :void
    ffi_func :ui_window_placeable, [], :bool
    ffi_func :ui_window_x, [], :int
    ffi_func :ui_window_y, [], :int
    ffi_func :ui_move_window, %i[int int], :void
    ffi_func :ui_show_window, %i[int], :void
    ffi_func :ui_window_shown, [], :bool
    ffi_func :tray_open, %i[str], :bool
    ffi_func :tray_show_progress, %i[str int], :void
    ffi_func :tray_next_event, [], :int
    ffi_func :tray_close, [], :void
    ffi_func :ui_screen_width, [], :int
    ffi_func :ui_screen_height, [], :int
    ffi_func :ui_begin_frame, %i[uint32], :void
    ffi_func :ui_end_frame, [], :void
    ffi_func :ui_skip_frame, [], :bool
    ffi_func :ui_set_extra_codepoints, %i[int_array int], :void
    ffi_func :ui_load_font, %i[int str int], :void
    ffi_func :ui_font_loaded, %i[int], :bool
    ffi_func :ui_glyph_slots, %i[int], :int
    ffi_func :ui_text_width, %i[int str float], :float
    ffi_func :ui_draw_text, %i[int str float float float uint32], :void
    ffi_func :ui_draw_rect, %i[float float float float uint32], :void
    ffi_func :ui_wheel_move, [], :float
    ffi_func :ui_mouse_x, [], :int
    ffi_func :ui_mouse_y, [], :int
    ffi_func :ui_mouse_buttons, [], :int
    ffi_func :ui_keys_pressed, %i[int_array int], :int
    ffi_func :ui_style_checkbox, %i[uint32 uint32 uint32], :void
    ffi_func :ui_draw_checkbox, %i[float float float bool], :void
    ffi_func :ui_pointer_on, %i[float float float float], :int
    ffi_func :ui_set_hand_cursor, %i[bool], :void
  end
end
