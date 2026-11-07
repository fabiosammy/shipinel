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

  # A 400 x 600 window whose page area starts `top` pixels down.
  def paint(screen, offset: 0.0, top: 0.0, overlay: Shipinel::DrawList.new)
    view = Shipinel::Viewport.new(offset, Shipinel::Rect.new(0.0, top, 400.0, 600.0 - top))
    Shipinel::Painter.new(screen, Shipinel::Frame.new(page, overlay, view)).paint
  end

  def test_draws_everything_shifted_up_by_the_scroll
    screen = FakeScreen.new
    paint(screen, offset: 100.0)

    assert_equal [[:rect, 0.0, 0x123456FF], [:text, "ação", 10.0], [:checkbox, 20.0, false], [:pointer, 20.0],
                  [:checkbox, 40.0, true], [:pointer, 40.0], [:pointer, 60.0]], screen.draws
  end

  # Scrolled 130 down, the box (100-110) and the text (110-137) end above
  # the window, except the text's last 7 pixels.
  def test_skips_what_the_window_does_not_show
    screen = FakeScreen.new
    paint(screen, offset: 130.0)

    assert_equal [:text, "ação", -20.0], screen.draws.first
  end

  # Moved 500 down, the first command starts at the window's bottom edge.
  def test_skips_what_is_below_the_window
    screen = FakeScreen.new
    paint(screen, offset: -500.0)

    assert_empty screen.draws
  end

  def test_overlay_is_drawn_last_and_not_scrolled
    overlay = Shipinel::DrawList.new
    overlay.add(Shipinel::Box.new(Shipinel::Rect.new(0.0, 0.0, 400.0, 50.0), 0xABCDEFFF))
    screen = FakeScreen.new
    paint(screen, offset: 100.0, overlay: overlay)

    assert_equal [:rect, 0.0, 0xABCDEFFF], screen.draws.last
  end

  def test_no_click_returns_nil
    assert_nil paint(FakeScreen.new)
  end

  def test_a_clicked_checkbox_is_returned_with_its_task_click
    click = paint(FakeScreen.new([140.0])).click

    assert_equal [5, true], [click.line_index, click.checked?]
  end

  def test_a_clicked_link_is_returned_with_its_url
    assert_equal "https://x.test", paint(FakeScreen.new([160.0])).url
  end

  def test_hand_cursor_only_over_something_clickable
    away = FakeScreen.new
    over = FakeScreen.new(over_tops: [160.0])
    paint(away)
    paint(over)

    assert_equal [false, true], [away.hand, over.hand]
  end

  # The checkbox at 120 is under a header that ends at 125; the one at 140
  # is below it.
  def test_nothing_under_the_header_can_be_clicked
    screen = FakeScreen.new([120.0, 140.0])
    click = paint(screen, offset: 125.0, top: 125.0).click

    assert_equal [5, [140.0, 160.0]], [click.line_index, screen.draws.select do |draw|
      draw.first == :pointer
    end.map(&:last)]
  end
end
