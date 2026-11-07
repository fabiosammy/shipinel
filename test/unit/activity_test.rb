# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/activity"

class ActivityTest < Minitest::Test
  def mouse(left, buttons: 0, wheel: 0.0) = Shipinel::MouseState.new(Shipinel::Point.new(left, 5.0), buttons, wheel)

  def rate_after(*mice)
    activity = Shipinel::Activity.new
    mice.each { |state| activity.note(state) }
    activity.frame_rate
  end

  def still(frames, left = 1.0) = Array.new(frames) { mouse(left) }

  def test_idle_window_runs_slowly
    assert_equal 10, rate_after(*still(31))
  end

  def test_wheel_button_or_movement_runs_fast
    assert_equal [60, 60, 60], [rate_after(*still(31), mouse(1.0, wheel: -1.0)),
                                rate_after(*still(31), mouse(1.0, buttons: 1)), rate_after(*still(31), mouse(2.0))]
  end

  def test_slows_down_half_a_second_after_the_last_input
    assert_equal [60, 10], [rate_after(mouse(2.0), *still(29, 2.0)), rate_after(mouse(2.0), *still(30, 2.0))]
  end
end
