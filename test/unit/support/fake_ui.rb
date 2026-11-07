# frozen_string_literal: true

# Stands in for the Spinel FFI module, which CRuby cannot load: records each
# call and answers like the C shim would. Used by the Screen and FontShim
# tests.
module Shipinel
  module UI
    def self.calls = (@calls ||= [])
    def self.record(*call, answer: nil) = calls.push(call) && answer
    def self.ui_open_window(*) = record(:open, *)
    def self.ui_window_ready = record(:ready, answer: true)
    def self.ui_window_should_close = record(:should_close, answer: false)
    def self.ui_close_window = record(:close)
    def self.ui_screen_width = record(:width, answer: 440)
    def self.ui_screen_height = record(:height, answer: 640)
    def self.ui_begin_frame(*) = record(:begin_frame, *)
    def self.ui_end_frame = record(:end_frame)
    def self.ui_set_frame_rate(*) = record(:rate, *)
    def self.ui_set_extra_codepoints(*) = record(:extra_codepoints, *)
    def self.ui_load_font(*) = record(:load_font, *)
    def self.ui_font_loaded(*) = record(:font_loaded, *, answer: false)
    def self.ui_glyph_slots(*) = record(:glyph_slots, *, answer: 9)
    def self.ui_text_width(*) = record(:text_width, *, answer: 42.5)
    def self.ui_draw_text(*) = record(:draw_text, *)
    def self.ui_draw_rect(*) = record(:draw_rect, *)
    def self.ui_wheel_move = record(:wheel, answer: -1.0)
    def self.ui_mouse_x = record(:mouse_x, answer: 12)
    def self.ui_mouse_y = record(:mouse_y, answer: 34)
    def self.ui_mouse_buttons = record(:mouse_buttons, answer: 3)
    def self.ui_style_checkbox(*) = record(:style_checkbox, *)
    def self.ui_draw_checkbox(*) = record(:checkbox, *)
    def self.ui_pointer_on(*) = record(:pointer_on, *, answer: @pointer || 2)

    def self.pointer=(answer)
      @pointer = answer
    end

    def self.ui_set_hand_cursor(*) = record(:hand_cursor, *)
  end
end
