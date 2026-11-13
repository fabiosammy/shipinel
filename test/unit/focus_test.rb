# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/focus"

# A page of four checkboxes (tasks on lines 1, 3, 5 and 7), 100 pixels
# apart, with text between them; a 400 x 150 window.
class FocusTest < Minitest::Test
  STYLE = Shipinel::TextStyle.new(0, 20.0, 0)

  def content
    @content ||= Shipinel::DrawList.new.tap do |list|
      [1, 3, 5, 7].each_with_index do |line, row|
        top = row * 100.0
        list.add(Shipinel::Checkbox.new(Shipinel::Rect.new(16.0, top, 17.0, 17.0),
                                        Shipinel::TaskClick.new(line, false)))
        list.add(Shipinel::TextRun.new("task ", Shipinel::Rect.new(40.0, top, 50.0, 27.0), STYLE))
      end
    end
  end

  def view(offset = 0.0)
    Shipinel::PageInView.new(content, Shipinel::Viewport.new(offset, Shipinel::Rect.new(0.0, 0.0, 400.0, 150.0)))
  end

  def keys(bits) = Shipinel::FocusKeys.new(bits)

  TAB = Shipinel::FocusKeys::NEXT
  SHIFT = Shipinel::FindKeys::SHIFT

  # Focus after these key presses, in turn, in `window`.
  def focused(*presses, window: view)
    presses.reduce(Shipinel::Focus.none) { |focus, bits| focus.after(keys(bits), window) }
  end

  def test_the_first_tab_lands_on_the_first_checkbox_in_view
    assert_equal [1, 5], [focused(TAB).line, focused(TAB, window: view(150.0)).line]
  end

  def test_tab_and_shift_tab_go_round_the_ends
    assert_equal [3, 1, 7], [focused(TAB, TAB).line, focused(TAB, TAB, TAB, TAB, TAB).line,
                             focused(TAB, TAB | SHIFT).line]
  end

  def test_space_presses_the_focused_checkbox_only
    pressed = focused(TAB, TAB, Shipinel::FocusKeys::TICK)

    assert_equal [true, 3, false], [pressed.pressed?, pressed.pressed_in(content).click.line_index,
                                    focused(Shipinel::FocusKeys::TICK).pressed?]
  end

  def test_escape_lets_go
    assert_equal(-1, focused(TAB, Shipinel::FindKeys::CLOSE).line)
  end

  # Line 7 is 300 pixels down, out of a 150-pixel window at the top: the
  # window goes to put it a third of the way down; in view, it stays.
  def test_aim_shows_the_focused_checkbox
    last = focused(TAB, TAB | SHIFT)

    assert_equal [250.0, false], [last.aim(view).offset, focused(TAB).aim(view).aimed?]
  end

  # Four bars around the checkbox at 16,0 (17 square): 2 pixels away, 2 wide.
  def test_the_ring_goes_round_the_checkbox_in_view
    overlay = Shipinel::DrawList.new
    focused(TAB).ring_into(overlay, view)

    assert_equal [[12.0, -4.0, 25.0, 2.0], [12.0, 19.0, 25.0, 2.0], [12.0, -4.0, 2.0, 25.0], [35.0, -4.0, 2.0, 25.0]],
                 sides_of(overlay)
  end

  # Left, top, width and height of each command in `list`.
  def sides_of(list)
    Array.new(list.size) do |position|
      rect = list.at(position).rect
      [rect.left, rect.top, rect.width, rect.height]
    end
  end

  def test_no_ring_when_out_of_view_or_none
    overlay = Shipinel::DrawList.new
    focused(TAB).ring_into(overlay, view(150.0))
    Shipinel::Focus.none.ring_into(overlay, view)

    assert_equal 0, overlay.size
  end

  def test_same_as
    assert_equal [true, false], [focused(TAB).same_as?(focused(TAB)), focused(TAB).same_as?(focused(TAB, TAB))]
  end
end
