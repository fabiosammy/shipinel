# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/painter"

class PainterTest < Minitest::Test
  # Records draws; the mouse is over the things whose top is in
  # `over_tops`, and clicks those whose top is in `click_tops`.
  class FakeScreen
    attr_reader :draws, :hand

    def initialize(click_tops = [], over_tops: [])
      @click_tops = click_tops
      @over_tops = over_tops + click_tops
      @draws = []
    end

    def use_hand_cursor(hand)
      @hand = hand
    end

    def pointer_on(rect)
      @draws << [:pointer, rect.top]
      return :away unless @over_tops.include?(rect.top)

      @click_tops.include?(rect.top) ? :clicked : :over
    end

    def draw_text(text, at, _style) = @draws << [:text, text, at.top]
    def draw_rect(rect, color) = @draws << [:rect, rect.top, color]

    def draw_checkbox(rect, checked)
      @draws << [:checkbox, rect.top, checked]
    end
  end

  STYLE = Shipinel::TextStyle.new(0, 20.0, 0xFFFFFFFF)

  def checkbox(top, line_index, checked)
    Shipinel::Checkbox.new(Shipinel::Rect.new(0.0, top, 17.0, 17.0), Shipinel::TaskClick.new(line_index, checked))
  end

  def page
    list = Shipinel::DrawList.new
    list.add(Shipinel::Box.new(Shipinel::Rect.new(0.0, 100.0, 50.0, 10.0), 0x123456FF))
    list.add(Shipinel::TextRun.new("ação", Shipinel::Rect.new(0.0, 110.0, 40.0, 27.0), STYLE))
    list.add(checkbox(120.0, 4, false))
    list.add(checkbox(140.0, 5, true))
    list.add(Shipinel::LinkArea.new(Shipinel::Rect.new(0.0, 160.0, 40.0, 27.0), "https://x.test"))
    list
  end

  def test_draws_everything_shifted_up_by_the_scroll
    screen = FakeScreen.new
    Shipinel::Painter.new(screen, Shipinel::Viewport.new(100.0, 0.0)).paint(page)

    assert_equal [[:rect, 0.0, 0x123456FF], [:text, "ação", 10.0], [:checkbox, 20.0, false], [:pointer, 20.0],
                  [:checkbox, 40.0, true], [:pointer, 40.0], [:pointer, 60.0]], screen.draws
  end

  def test_no_click_returns_nil
    assert_nil Shipinel::Painter.new(FakeScreen.new, Shipinel::Viewport.new(0.0, 0.0)).paint(page)
  end

  def test_a_clicked_checkbox_is_returned_with_its_task_click
    click = Shipinel::Painter.new(FakeScreen.new([140.0]), Shipinel::Viewport.new(0.0, 0.0)).paint(page).click

    assert_equal [5, true], [click.line_index, click.checked?]
  end

  def test_a_clicked_link_is_returned_with_its_url
    assert_equal "https://x.test",
                 Shipinel::Painter.new(FakeScreen.new([160.0]), Shipinel::Viewport.new(0.0, 0.0)).paint(page).url
  end

  def test_hand_cursor_only_over_something_clickable
    away = FakeScreen.new
    over = FakeScreen.new(over_tops: [160.0])
    Shipinel::Painter.new(away, Shipinel::Viewport.new(0.0, 0.0)).paint(page)
    Shipinel::Painter.new(over, Shipinel::Viewport.new(0.0, 0.0)).paint(page)

    assert_equal [false, true], [away.hand, over.hand]
  end

  # The checkbox at 120 is under a header that ends at 125; the one at 140
  # is below it.
  def test_nothing_under_the_header_can_be_clicked
    screen = FakeScreen.new([120.0, 140.0])
    click = Shipinel::Painter.new(screen, Shipinel::Viewport.new(0.0, 125.0)).paint(page).click

    assert_equal [5, [140.0, 160.0]], [click.line_index, screen.draws.select do |draw|
      draw.first == :pointer
    end.map(&:last)]
  end
end
