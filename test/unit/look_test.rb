# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/frame"
require_relative "../../lib/shipinel/task_toggler"

# Frame#look: what decides whether a frame is drawn again.
class LookTest < Minitest::Test
  # A page with one checkbox at 16,100 (17 px square), scrolled `offset`
  # under a 50 px header.
  def frame(offset)
    content = Shipinel::DrawList.new
    content.add(Shipinel::TextRun.new("texto", Shipinel::Rect.new(40.0, 100.0, 50.0, 27.0),
                                      Shipinel::TextStyle.new(0, 20.0, 0)))
    content.add(Shipinel::Checkbox.new(Shipinel::Rect.new(16.0, 100.0, 17.0, 17.0), Shipinel::TaskClick.new(0, false)))
    view = Shipinel::Viewport.new(offset, Shipinel::Rect.new(0.0, 50.0, 400.0, 300.0))
    Shipinel::Frame.new(content, Shipinel::DrawList.new, view)
  end

  def input(left, top, buttons = 0)
    Shipinel::Input.new(Shipinel::Point.new(left, top), buttons, 0.0, Shipinel::KeyPress.new(0, ""))
  end

  # At offset 0 the checkbox is drawn 50 px lower, under the header.
  def test_the_clickable_under_the_pointer_is_found_where_it_is_drawn
    page = frame(0.0)

    assert_equal [1, -1, -1], [page.clickable_at(Shipinel::Point.new(20.0, 155.0)),
                               page.clickable_at(Shipinel::Point.new(60.0, 155.0)),
                               page.clickable_at(Shipinel::Point.new(20.0, 105.0))]
  end

  # Scrolled 110 px, the checkbox starts at 40, under the header's 50:
  # Painter clicks nothing there, so nothing is hovered either.
  def test_a_clickable_under_the_header_is_not_under_the_pointer
    assert_equal(-1, frame(110.0).clickable_at(Shipinel::Point.new(20.0, 52.0)))
  end

  def test_moving_over_text_looks_the_same
    page = frame(0.0)

    assert page.look(input(60.0, 160.0)).same_as?(page.look(input(70.0, 170.0)))
  end

  def test_entering_a_checkbox_or_pressing_looks_different
    page = frame(0.0)
    rest = page.look(input(60.0, 160.0))

    refute rest.same_as?(page.look(input(20.0, 155.0)))
    refute rest.same_as?(page.look(input(60.0, 160.0, Shipinel::Input::DOWN)))
  end

  def test_scrolling_looks_different
    refute frame(0.0).look(input(60.0, 160.0)).same_as?(frame(48.0).look(input(60.0, 160.0)))
  end

  def test_no_look_matches_none
    refute Shipinel::Look.none.same_as?(frame(0.0).look(input(0.0, 0.0)))
  end
end
