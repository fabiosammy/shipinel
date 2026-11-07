# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/scrollbar"

class ScrollbarTest < Minitest::Test
  AREA = Shipinel::Rect.new(0.0, 0.0, 400.0, 300.0)

  def rect(rect) = [rect.left, rect.top, rect.width, rect.height].map { |value| value.round(1) }

  def test_needed_only_for_a_page_taller_than_the_window
    assert_equal [true, false],
                 [Shipinel::Scrollbar.new(301.0, AREA, 0.0).needed?, Shipinel::Scrollbar.new(300.0, AREA, 0.0).needed?]
  end

  def test_track_along_the_right_edge
    assert_equal [389.0, 0.0, 8.0, 300.0], rect(Shipinel::Scrollbar.new(1000.0, AREA, 0.0).track)
  end

  def test_thumb_shows_the_share_and_position_of_the_window
    assert_equal [389.0, 105.0, 8.0, 90.0], rect(Shipinel::Scrollbar.new(1000.0, AREA, 350.0).thumb)
  end

  def test_thumb_never_shorter_than_its_minimum
    assert_in_delta 24.0, Shipinel::Scrollbar.new(100_000.0, AREA, 0.0).thumb.height
  end

  def test_offset_for_a_thumb_position_stays_in_range
    bar = Shipinel::Scrollbar.new(1000.0, AREA, 0.0)

    assert_equal [350.0, 0.0, 700.0], [bar.offset_for(105.0), bar.offset_for(-50.0), bar.offset_for(900.0)]
  end

  # Below a 50-pixel header: same sizes, moved down by 50.
  def test_area_below_a_header
    bar = Shipinel::Scrollbar.new(1000.0, Shipinel::Rect.new(0.0, 50.0, 400.0, 300.0), 350.0)

    assert_equal [[389.0, 50.0, 8.0, 300.0], [389.0, 155.0, 8.0, 90.0], 350.0],
                 [rect(bar.track), rect(bar.thumb), bar.offset_for(155.0)]
  end
end
