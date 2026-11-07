# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/screen"

# Stands in for the Spinel FFI module, which CRuby cannot load: records each
# call and answers like the C shim would.
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
    def self.ui_load_font(*) = record(:load_font, *)
    def self.ui_font_loaded(*) = record(:font_loaded, *, answer: false)
    def self.ui_text_width(*) = record(:text_width, *, answer: 42.5)
    def self.ui_draw_text(*) = record(:draw_text, *)
    def self.ui_draw_rect(*) = record(:draw_rect, *)
    def self.ui_wheel_move = record(:wheel, answer: -1.0)
    def self.ui_style_checkbox(*) = record(:style_checkbox, *)
    def self.ui_checkbox(*) = record(:checkbox, *, answer: true)
  end
end

class ScreenTest < Minitest::Test
  RECT = Shipinel::Rect.new(1.0, 2.0, 3.0, 4.0)

  STYLE = Shipinel::TextStyle.new(1, 18.0, 0xFFFFFFFF)

  def setup
    Shipinel::UI.calls.clear
    @screen = Shipinel::Screen.new
  end

  def test_window_lifecycle
    @screen.open(440, 640, "shipinel")

    assert_predicate @screen, :ready?
    refute_predicate @screen, :closing?
    @screen.close

    assert_equal [[:open, 440, 640, "shipinel"], [:ready], [:should_close], [:close]], Shipinel::UI.calls
  end

  def test_area_and_frames
    area = @screen.area

    assert_equal [0.0, 0.0, 440.0, 640.0], [area.left, area.top, area.width, area.height]
    @screen.begin_frame(0x000000FF)
    @screen.end_frame

    assert_equal [[:width], [:height], [:begin_frame, 0x000000FF], [:end_frame]], Shipinel::UI.calls
  end

  def test_font_that_fails_to_load_is_reported
    @screen.load_font(0, "/nope.ttf", 20)

    refute @screen.font_loaded?(0)
    assert_equal [[:load_font, 0, "/nope.ttf", 20], [:font_loaded, 0]], Shipinel::UI.calls
  end

  def test_text_uses_the_style
    assert_in_delta 42.5, @screen.text_measure.text_width("ação", STYLE)
    @screen.draw_text("ação", Shipinel::Point.new(1.0, 2.0), STYLE)

    assert_equal [[:text_width, 1, "ação", 18.0], [:draw_text, 1, "ação", 1.0, 2.0, 18.0, 0xFFFFFFFF]],
                 Shipinel::UI.calls
  end

  def test_rectangles_and_wheel
    @screen.draw_rect(RECT, 0x11223344)

    assert_in_delta(-1.0, @screen.wheel_move)
    assert_equal [[:draw_rect, 1.0, 2.0, 3.0, 4.0, 0x11223344], [:wheel]], Shipinel::UI.calls
  end

  def test_checkboxes
    @screen.style_checkboxes(1, 2, 3)

    assert @screen.checkbox_clicked?(RECT, true)
    assert_equal [[:style_checkbox, 1, 2, 3], [:checkbox, 1.0, 2.0, 3.0, true]],
                 Shipinel::UI.calls
  end
end
