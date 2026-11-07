# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_ui"
require_relative "../../lib/shipinel/screen"

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

  def test_text_and_rectangles
    @screen.draw_text("ação", Shipinel::Point.new(1.0, 2.0), STYLE)
    @screen.draw_rect(RECT, 0x11223344)

    assert_equal [[:draw_text, 1, "ação", 1.0, 2.0, 18.0, 0xFFFFFFFF], [:draw_rect, 1.0, 2.0, 3.0, 4.0, 0x11223344]],
                 Shipinel::UI.calls
  end

  def test_input
    assert_in_delta(-1.0, @screen.wheel_move)
    @screen.draw_checkbox(RECT, true)

    assert_equal [[:wheel], [:checkbox, 1.0, 2.0, 3.0, true]], Shipinel::UI.calls
  end

  def test_pointer_states
    states = [2, 1, 0].map do |answer|
      Shipinel::UI.pointer = answer
      @screen.pointer_on(RECT)
    end

    assert_equal %i[clicked over away], states
  ensure
    Shipinel::UI.pointer = nil
  end

  def test_hand_cursor
    @screen.use_hand_cursor(true)

    assert_equal [[:hand_cursor, true]], Shipinel::UI.calls
  end

  def test_checkbox_style_and_fonts
    @screen.style_checkboxes(1, 2, 3)

    assert_equal [[:style_checkbox, 1, 2, 3]], Shipinel::UI.calls
    assert_instance_of Shipinel::FontShim, @screen.font_shim
  end
end
