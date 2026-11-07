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

    style = [:style_checkbox, Shipinel::Theme::Checkbox::BORDER, Shipinel::Theme::Checkbox::HOVER,
             Shipinel::Theme::Checkbox::CHECK]

    assert_equal [[:open, 440, 640, "shipinel"], style, [:ready], [:should_close], [:close]], Shipinel::UI.calls
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

  def test_skipped_frame_waits_and_reads_input_without_drawing
    @screen.skip_frame

    assert_equal [[:skip_frame]], Shipinel::UI.calls
  end

  def test_mouse
    mouse = @screen.mouse

    assert_equal [12.0, 34.0, -1.0, true, true], [mouse.at.left, mouse.at.top, mouse.wheel, mouse.down?, mouse.pressed?]
  end

  def test_checkbox
    @screen.draw_checkbox(RECT, true)

    assert_equal [[:checkbox, 1.0, 2.0, 3.0, true]], Shipinel::UI.calls
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

  def test_fonts
    assert_instance_of Shipinel::FontShim, @screen.font_shim
  end
end
