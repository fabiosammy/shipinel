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
    @screen.open(Shipinel::WindowPlace.new(Shipinel::Rect.new(30.0, 40.0, 500.0, 700.0), true), "shipinel")

    assert_predicate @screen, :ready?
    refute_predicate @screen, :closing?
    @screen.close

    style = [:style_checkbox, Shipinel::Theme::Checkbox::BORDER, Shipinel::Theme::Checkbox::HOVER,
             Shipinel::Theme::Checkbox::CHECK]

    assert_equal [[:open, 500, 700, "shipinel"], [:move, 30, 40], style, [:ready], [:should_close], [:close]],
                 Shipinel::UI.calls
  end

  def test_a_window_placed_by_the_window_system_is_not_moved
    @screen.open(Shipinel::WindowPlace.sized(440, 640), "shipinel")

    assert_equal [:open, 440, 640, "shipinel"], Shipinel::UI.calls.first
    refute(Shipinel::UI.calls.any? { |call| call.first == :move })
  end

  def test_placement_and_frames
    place = @screen.placement
    rect = place.rect

    assert_equal [7.0, 9.0, 440.0, 640.0, true], [rect.left, rect.top, rect.width, rect.height, place.placed?]
    Shipinel::UI.calls.clear
    @screen.begin_frame(0x000000FF)
    @screen.end_frame

    assert_equal [[:begin_frame, 0x000000FF], [:end_frame]], Shipinel::UI.calls
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

  def test_input_mouse
    input = @screen.input

    assert_equal [12.0, 34.0, -1.0, true, true], [input.at.left, input.at.top, input.wheel, input.down?, input.pressed?]
  end

  def test_input_keys
    keys = @screen.input.keys

    read = Shipinel::UI.calls.find { |call| call.first == :keys }

    assert_equal [true, [:keys, Shipinel::Keyboard.watched, 22]], [keys.pressed?, read]
  end

  # Typed characters are read until the shim answers 0.
  def test_input_typed
    Shipinel::UI.typed = ["a".ord, "ç".ord, "1".ord]

    assert_equal "aç1", @screen.input.keys.typed
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
