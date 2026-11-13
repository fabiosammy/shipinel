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
    Shipinel::KeyPress.new(codes.sum { |code| 1 << watched.find_index(code) }, "")
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

  def with_control(code) = Shipinel::KeyPress.new(watched_bit(code) | Shipinel::KeyPress::Selecting::CONTROL, "")

  # Ctrl+C and Ctrl+A need Control; Control alone is not a key press.
  def test_copy_and_select_all_need_control
    assert_equal [false, true, true, false],
                 [press(K::Selecting::C).commands.copy?, with_control(K::Selecting::C).commands.copy?,
                  with_control(K::Selecting::A).commands.select_all?, press(K::Selecting::A).commands.select_all?]
  end

  def test_control_alone_is_not_a_key_press
    refute_predicate Shipinel::KeyPress.new(Shipinel::KeyPress::Selecting::CONTROL, ""), :pressed?
  end

  F = K::Finding

  def finding(bits, typed = "") = Shipinel::KeyPress.new(bits, typed).for_finding

  def find_bit(code) = watched_bit(code)

  def test_ctrl_f_opens_the_find_bar
    control = Shipinel::KeyPress::Selecting::CONTROL

    assert_equal [true, false], [finding(find_bit(F::F) | control).open?, finding(find_bit(F::F)).open?]
  end

  def test_escape_closes_and_backspace_erases
    assert_equal [true, true], [finding(find_bit(F::ESCAPE)).close?, finding(find_bit(F::BACKSPACE)).erase?]
  end

  # Either Enter: the next match; with Shift: the previous; Shift alone: none.
  def test_enter_steps
    shift = Shipinel::FindKeys::SHIFT

    assert_equal [1, 1, -1, 0], [finding(find_bit(F::ENTER)).step, finding(find_bit(F::KEYPAD_ENTER)).step,
                                 finding(find_bit(F::ENTER) | shift).step, finding(shift).step]
  end

  # Typing is a key press; Shift alone is not.
  def test_typing_is_a_key_press
    shift_alone = Shipinel::KeyPress.new(Shipinel::FindKeys::SHIFT, "")

    assert_equal [true, false, "ab"],
                 [Shipinel::KeyPress.new(0, "ab").pressed?, shift_alone.pressed?, finding(0, "ab").typed]
  end

  # While the find bar is open, j, k, the zoom keys, h and u are typed, not
  # obeyed; the arrows and Page keys still scroll.
  def test_letters_are_left_out_while_finding
    letters = press(K::Lines::J, K::Lines::K, K::Zoom::EQUAL, K::Zoom::ZERO, K::HEADER, K::UNDO).while_finding
    arrows = press(K::Lines::DOWN, K::Jumps::PAGE_DOWN).while_finding

    assert_equal [false, 100.0 + 48.0 + 300.0], [letters.pressed?, arrows.scrolled(100.0, BAR)]
  end

  def focusing(*codes) = press(*codes).for_focus

  # Tab: the next checkbox, Shift+Tab the previous; Space ticks; Escape
  # lets go.
  def test_focus_keys
    shift_tab = Shipinel::FocusKeys.new(watched_bit(K::Focusing::TAB) | Shipinel::FindKeys::SHIFT)

    assert_equal [1, -1, 0, true, true], [focusing(K::Focusing::TAB).step, shift_tab.step, focusing.step,
                                          focusing(K::Focusing::SPACE).tick?, focusing(F::ESCAPE).clear?]
  end

  def test_tab_and_space_are_left_out_while_finding
    refute_predicate press(K::Focusing::TAB, K::Focusing::SPACE).while_finding, :pressed?
  end
end
