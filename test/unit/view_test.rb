# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/view"

class ViewTest < Minitest::Test
  K = Shipinel::Keyboard

  def press(code) = Shipinel::KeyPress.new(1 << K.watched.find_index(code))
  def size_after(size, code) = Shipinel::View.new(size, 20, true).after(press(code)).size

  def test_zoom_steps_two_pixels
    assert_equal [22, 18], [size_after(20, K::Zoom::EQUAL), size_after(20, K::Zoom::MINUS)]
  end

  def test_zoom_stays_within_the_font_size_limits
    assert_equal [72, 8], [size_after(72, K::Zoom::EQUAL), size_after(8, K::Zoom::MINUS)]
  end

  def test_zero_goes_back_to_the_starting_size
    assert_equal 20, size_after(40, K::Zoom::ZERO)
  end

  def test_h_toggles_the_header
    view = Shipinel::View.starting_at(20)
    hidden = view.after(press(K::HEADER))

    assert_equal [true, false, true], [view.header?, hidden.header?, hidden.after(press(K::HEADER)).header?]
  end
end
