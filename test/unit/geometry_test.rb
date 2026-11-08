# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/geometry"
require_relative "../../lib/shipinel/input"

class GeometryTest < Minitest::Test
  def test_points_are_the_same_by_position
    point = Shipinel::Point.new(1.0, 2.0)

    assert_equal [true, false],
                 [point.same_as?(Shipinel::Point.new(1.0, 2.0)), point.same_as?(Shipinel::Point.new(1.0, 3.0))]
  end

  def test_below_leaves_the_rest_of_a_rect
    rect = Shipinel::Rect.new(0.0, 10.0, 400.0, 300.0).below(50.0)

    assert_equal [0.0, 60.0, 400.0, 250.0], [rect.left, rect.top, rect.width, rect.height]
  end

  # An area from 50 to 350, scrolled 100 into the page.
  def test_viewport_shift_and_what_it_shows
    view = Shipinel::Viewport.new(100.0, Shipinel::Rect.new(0.0, 50.0, 400.0, 300.0))
    shown = [40.0, 45.0, 349.0, 350.0].map { |top| view.shows?(Shipinel::Rect.new(0.0, top, 10.0, 10.0)) }

    assert_equal [50.0, 50.0, [false, true, true, false]], [view.shift, view.top, shown]
  end

  def test_input_is_active_with_a_button_the_wheel_or_a_key
    at = Shipinel::Point.new(0.0, 0.0)

    inputs = [[0, 0.0, 0], [1, 0.0, 0], [0, 1.0, 0], [0, 0.0, 4]].map do |buttons, wheel, keys|
      Shipinel::Input.new(at, buttons, wheel, Shipinel::KeyPress.new(keys)).active?
    end

    assert_equal [false, true, true, true], inputs
  end
end
