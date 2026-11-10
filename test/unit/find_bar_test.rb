# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/find_bar"

# The find bar at the bottom of a 400 x 300 window. FakeShim fonts make a
# character 10 pixels wide at size 20.
class FindBarTest < Minitest::Test
  STYLE = Shipinel::TextStyle.new(0, 20.0, 0xFFFFFFFF)
  WINDOW = Shipinel::Rect.new(0.0, 0.0, 400.0, 300.0)
  FONTS = fake_font_set

  def content
    Shipinel::DrawList.new.tap do |list|
      list.add(Shipinel::TextRun.new("ship the demo", Shipinel::Rect.new(0.0, 0.0, 130.0, 27.0), STYLE))
    end
  end

  def search(typed)
    open = Shipinel::FindKeys.new(Shipinel::FindKeys::OPEN | Shipinel::KeyPress::Selecting::CONTROL, "")
    opened = Shipinel::Search.none.after(open, content, FONTS)
    opened.after(Shipinel::FindKeys.new(0, typed), content, FONTS)
  end

  def texts(search)
    overlay = Shipinel::DrawList.new
    Shipinel::FindBar.new(search, STYLE, WINDOW, FONTS).add_to(overlay)
    Array.new(overlay.size) { |position| overlay.at(position) }.grep(Shipinel::TextRun).map(&:text)
  end

  def test_closed_it_takes_no_room_and_draws_nothing
    assert_equal [0.0, []], [Shipinel::FindBar.new(Shipinel::Search.none, STYLE, WINDOW, FONTS).height, texts(Shipinel::Search.none)]
  end

  def test_open_it_shows_the_query_and_where_it_is
    assert_equal [["Find: "], ["Find: e", "1 of 2"], ["Find: x", "no matches"]],
                 [texts(search("")), texts(search("e")), texts(search("x"))]
  end

  # The band sits on the window's bottom edge.
  def test_it_is_pinned_to_the_bottom
    overlay = Shipinel::DrawList.new
    bar = Shipinel::FindBar.new(search("e"), STYLE, WINDOW, FONTS)
    bar.add_to(overlay)

    assert_in_delta(300.0, overlay.at(0).rect.top + bar.height)
  end
end
