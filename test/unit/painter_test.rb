# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/painter"

class PainterTest < Minitest::Test
  # Records draws; "clicks" the checkboxes whose top is listed.
  class FakeScreen
    attr_reader :draws

    def initialize(click_tops = [])
      @click_tops = click_tops
      @draws = []
    end

    def draw_text(text, at, _style) = @draws << [:text, text, at.top]
    def draw_rect(rect, color) = @draws << [:rect, rect.top, color]

    def checkbox_clicked?(rect, checked)
      @draws << [:checkbox, rect.top, checked]
      @click_tops.include?(rect.top)
    end

    def clicked_in?(rect)
      @draws << [:link, rect.top]
      @click_tops.include?(rect.top)
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
    Shipinel::Painter.paint(screen, page, 100.0)

    assert_equal [[:rect, 0.0, 0x123456FF], [:text, "ação", 10.0], [:checkbox, 20.0, false], [:checkbox, 40.0, true],
                  [:link, 60.0]], screen.draws
  end

  def test_no_click_returns_nil
    assert_nil Shipinel::Painter.paint(FakeScreen.new, page, 0.0)
  end

  def test_a_clicked_checkbox_is_returned_with_its_task_click
    click = Shipinel::Painter.paint(FakeScreen.new([140.0]), page, 0.0).click

    assert_equal [5, true], [click.line_index, click.checked?]
  end

  def test_a_clicked_link_is_returned_with_its_url
    assert_equal "https://x.test", Shipinel::Painter.paint(FakeScreen.new([160.0]), page, 0.0).url
  end
end
