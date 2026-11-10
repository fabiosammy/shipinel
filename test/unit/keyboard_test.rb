# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/keyboard"

# Scrolling a 1000-pixel page in a 400 x 300 window from 100 pixels down.
class KeyboardTest < Minitest::Test
  K = Shipinel::Keyboard
  BAR = Shipinel::Scrollbar.new(1000.0, Shipinel::Rect.new(0.0, 0.0, 400.0, 300.0), 0.0)

  # A KeyPress with these watched keys pressed.
  def press(*codes)
    watched = K.watched
    Shipinel::KeyPress.new(codes.sum { |code| 1 << watched.find_index(code) })
  end

  def scrolled(*codes) = press(*codes).scrolled(100.0, BAR)
  def watched_bit(code) = 1 << K.watched.find_index(code)

  def test_nothing_pressed_moves_nothing
    assert_equal [false, 100.0, 0], [press.pressed?, scrolled, press.zoom_step]
  end

  def test_lines_with_vim_keys_and_arrows
    assert_equal [148.0, 148.0, 52.0, 52.0, 100.0], [scrolled(K::Lines::J), scrolled(K::Lines::DOWN), scrolled(K::Lines::K),
                                                     scrolled(K::Lines::UP), scrolled(K::Lines::J, K::Lines::K)]
  end

  def test_pages_and_ends
    assert_equal [400.0, -200.0, 0.0, 700.0], [scrolled(K::Jumps::PAGE_DOWN), scrolled(K::Jumps::PAGE_UP),
                                               scrolled(K::Jumps::HOME), scrolled(K::Jumps::END_KEY)]
  end

  def test_zoom_with_main_keys_and_keypad
    assert_equal [1, 1, -1, -1, true], [press(K::Zoom::EQUAL).zoom_step, press(K::Zoom::KEYPAD_PLUS).zoom_step,
                                        press(K::Zoom::MINUS).zoom_step, press(K::Zoom::KEYPAD_MINUS).zoom_step,
                                        press(K::Zoom::ZERO).zoom_reset?]
  end

  def test_h_toggles_the_header
    assert_equal [true, false], [press(K::HEADER).header?, press(K::Lines::J).header?]
    assert_equal [true, false], [press(K::UNDO).undo?, press(K::HEADER).undo?]
  end

  def with_control(code) = Shipinel::KeyPress.new(watched_bit(code) | Shipinel::KeyPress::Selecting::CONTROL)

  # Ctrl+C and Ctrl+A need Control; Control alone is not a key press.
  def test_copy_and_select_all_need_control
    assert_equal [false, true, true, false],
                 [press(K::Selecting::C).copy?, with_control(K::Selecting::C).copy?,
                  with_control(K::Selecting::A).select_all?, press(K::Selecting::A).select_all?]
  end

  def test_control_alone_is_not_a_key_press
    refute_predicate Shipinel::KeyPress.new(Shipinel::KeyPress::Selecting::CONTROL), :pressed?
  end
end
