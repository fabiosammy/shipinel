# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/scroll"

# A 1000-pixel page in a 400 x 300 window: the thumb is 90 tall, travels
# 210, and the page scrolls 700.
class ScrollTest < Minitest::Test
  AREA = Shipinel::Rect.new(0.0, 0.0, 400.0, 300.0)
  TRACK_X = 393.0

  def setup
    @scroll = Shipinel::Scroll.new
  end

  def bar(page_height = 1000.0) = Shipinel::Scrollbar.new(page_height, AREA, @scroll.offset)

  def mouse(top, buttons: 0, wheel: 0.0, left: TRACK_X)
    Shipinel::Input.new(Shipinel::Point.new(left, top), buttons, wheel, Shipinel::KeyPress.new(0))
  end

  def test_starts_at_the_top
    assert_in_delta 0.0, @scroll.offset
  end

  def test_wheel_toward_the_user_scrolls_down_one_step
    @scroll.apply(mouse(0.0, wheel: -1.0), bar)

    assert_in_delta 48.0, @scroll.offset
  end

  def test_wheel_stops_at_both_ends
    @scroll.apply(mouse(0.0, wheel: 3.0), bar)
    top = @scroll.offset
    @scroll.apply(mouse(0.0, wheel: -100.0), bar)

    assert_equal [0.0, 700.0], [top, @scroll.offset]
  end

  def test_short_page_never_moves
    @scroll.apply(mouse(0.0, wheel: -5.0), bar(200.0))

    assert_in_delta 0.0, @scroll.offset
  end

  def test_offset_survives_and_is_kept_in_range_after_a_shorter_reload
    @scroll.apply(mouse(0.0, wheel: -10.0), bar)
    @scroll.apply(mouse(0.0), bar(500.0))

    assert_in_delta 200.0, @scroll.offset
  end

  def test_dragging_the_thumb_moves_the_page
    @scroll.apply(mouse(10.0, buttons: 3), bar)
    @scroll.apply(mouse(115.0, buttons: 1), bar)

    assert_in_delta 350.0, @scroll.offset
  end

  def test_letting_go_ends_the_drag
    @scroll.apply(mouse(10.0, buttons: 3), bar)
    @scroll.apply(mouse(115.0), bar)
    @scroll.apply(mouse(200.0), bar)

    assert_in_delta 0.0, @scroll.offset
  end

  def test_pressing_the_track_below_the_thumb_moves_a_window_down
    @scroll.apply(mouse(250.0, buttons: 3), bar)

    assert_in_delta 300.0, @scroll.offset
  end

  def test_pressing_the_track_above_the_thumb_moves_a_window_up
    @scroll.apply(mouse(0.0, wheel: -10.0), bar)
    @scroll.apply(mouse(5.0, buttons: 3), bar)

    assert_in_delta 180.0, @scroll.offset
  end

  def test_pressing_outside_the_bar_does_nothing
    @scroll.apply(mouse(10.0, buttons: 3, left: 100.0), bar)

    assert_in_delta 0.0, @scroll.offset
  end

  # The pointer away from the bar, one key pressed.
  def key(code)
    pressed = Shipinel::KeyPress.new(1 << Shipinel::Keyboard.watched.find_index(code))
    Shipinel::Input.new(Shipinel::Point.new(100.0, 0.0), 0, 0.0, pressed)
  end

  def test_line_keys_move_one_step
    @scroll.apply(key(Shipinel::Keyboard::Lines::J), bar)
    @scroll.apply(key(Shipinel::Keyboard::Lines::DOWN), bar)
    @scroll.apply(key(Shipinel::Keyboard::Lines::K), bar)

    assert_in_delta 48.0, @scroll.offset
  end

  def test_page_keys_move_a_window
    @scroll.apply(key(Shipinel::Keyboard::Jumps::PAGE_DOWN), bar)

    assert_in_delta 300.0, @scroll.offset
  end

  def test_home_and_end
    @scroll.apply(key(Shipinel::Keyboard::Jumps::END_KEY), bar)
    bottom = @scroll.offset
    @scroll.apply(key(Shipinel::Keyboard::Jumps::HOME), bar)

    assert_equal [700.0, 0.0], [bottom, @scroll.offset]
  end
end
