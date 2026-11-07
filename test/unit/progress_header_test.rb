# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/progress_header"
require_relative "../../lib/shipinel/markdown/parser"

# A 400-pixel-wide window, body text 20 (status text 17, line 22.95).
class ProgressHeaderTest < Minitest::Test
  STYLES = Shipinel::Styles.new(20.0)

  def header(source)
    Shipinel::ProgressHeader.new(Shipinel::Markdown::Parser.parse(source).task_progress, STYLES, 400.0)
  end

  def commands(source)
    page = Shipinel::DrawList.new
    header(source).add_to(page)
    Array.new(page.size) { |position| page.at(position) }
  end

  def rect(command) = [command.rect.left, command.rect.top, command.rect.width, command.rect.height].map { it.round(2) }

  def test_no_tasks_no_header
    assert_equal [0.0, []], [header("texto\n").height, commands("texto\n")]
  end

  def test_band_label_and_bar_filled_by_the_share
    band, label, track, fill = commands("- [x] a\n- [ ] b\n- [ ] c\n- [ ] d\n")

    assert_equal [[0.0, 0.0, 400.0, 50.95], "1 of 4 tasks done · 25%", [16.0, 8.0], [16.0, 38.95, 368.0, 4.0],
                  [16.0, 38.95, 92.0, 4.0], Shipinel::Theme::Progress::FILL],
                 [rect(band), label.text, rect(label).first(2), rect(track), rect(fill), fill.color]
  end

  def test_bar_turns_green_when_everything_is_done
    assert_equal Shipinel::Theme::Progress::COMPLETE, commands("- [x] a\n").last.color
  end
end
