# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/scroll"

class ScrollTest < Minitest::Test
  def setup
    @scroll = Shipinel::Scroll.new
  end

  def test_starts_at_the_top
    assert_in_delta 0.0, @scroll.offset
  end

  def test_wheel_toward_the_user_scrolls_down_one_step
    @scroll.apply(-1.0, 1000.0, 400.0)

    assert_in_delta 48.0, @scroll.offset
  end

  def test_never_above_the_top
    @scroll.apply(3.0, 1000.0, 400.0)

    assert_in_delta 0.0, @scroll.offset
  end

  def test_stops_where_the_page_end_reaches_the_bottom
    @scroll.apply(-100.0, 1000.0, 400.0)

    assert_in_delta 600.0, @scroll.offset
  end

  def test_short_page_never_moves
    @scroll.apply(-5.0, 300.0, 400.0)

    assert_in_delta 0.0, @scroll.offset
  end

  def test_offset_survives_and_is_clamped_after_a_shorter_reload
    @scroll.apply(-10.0, 1000.0, 400.0)
    @scroll.apply(0.0, 700.0, 400.0)

    assert_in_delta 300.0, @scroll.offset
  end
end
