# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/activity"

class ActivityTest < Minitest::Test
  def mouse(left, buttons: 0, wheel: 0.0) = Shipinel::MouseState.new(Shipinel::Point.new(left, 5.0), buttons, wheel)

  def pace_after(*mice, changed: false)
    activity = Shipinel::Activity.new
    mice.each { |state| activity.note(state) }
    activity.pace(changed)
  end

  def still(frames, left = 1.0) = Array.new(frames) { mouse(left) }

  def test_wheel_button_or_movement_is_drawn
    assert_equal [true, true, true], [pace_after(*still(40), mouse(1.0, wheel: -1.0)).redraw?,
                                      pace_after(*still(40), mouse(1.0, buttons: 1)).redraw?,
                                      pace_after(*still(40), mouse(2.0)).redraw?]
  end

  def test_stops_drawing_half_a_second_after_the_last_input
    assert_equal [true, false],
                 [pace_after(mouse(2.0), *still(29, 2.0)).redraw?, pace_after(mouse(2.0), *still(31, 2.0)).redraw?]
  end

  def test_busy_frames_are_always_drawn
    assert_predicate pace_after(mouse(2.0)), :redraw?
  end

  # 31 still frames: the first moves from nowhere, then 30 quiet ones.
  def test_idle_page_is_drawn_only_when_it_changed
    assert_equal [false, true], [pace_after(*still(32)).redraw?, pace_after(*still(32), changed: true).redraw?]
  end

  def test_idle_page_is_drawn_again_every_two_seconds
    redrawn = (31..272).select { |frames| pace_after(*still(frames)).redraw? }

    assert_equal [31, 151, 271], redrawn
  end
end
