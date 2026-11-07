# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/activity"

class ActivityTest < Minitest::Test
  def mouse(left, buttons: 0, wheel: 0.0) = Shipinel::MouseState.new(Shipinel::Point.new(left, 5.0), buttons, wheel)

  def due_after?(*mice)
    activity = Shipinel::Activity.new
    mice.each { |state| activity.note(state) }
    activity.due?
  end

  def still(frames, left = 1.0) = Array.new(frames) { mouse(left) }

  def test_wheel_button_or_movement_is_drawn
    assert_equal [true, true, true], [due_after?(*still(40), mouse(1.0, wheel: -1.0)),
                                      due_after?(*still(40), mouse(1.0, buttons: 1)),
                                      due_after?(*still(40), mouse(2.0))]
  end

  def test_stops_drawing_half_a_second_after_the_last_input
    assert_equal [true, false],
                 [due_after?(mouse(2.0), *still(29, 2.0)), due_after?(mouse(2.0), *still(31, 2.0))]
  end

  def test_busy_frames_are_always_drawn
    assert due_after?(mouse(2.0))
  end

  def test_idle_page_is_drawn_again_every_two_seconds
    redrawn = (31..272).select { |frames| due_after?(*still(frames)) }

    assert_equal [31, 151, 271], redrawn
  end
end
