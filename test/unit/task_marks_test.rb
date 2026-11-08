# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/layout"
require_relative "../../lib/shipinel/markdown/parser"

# What the page points out besides the Markdown: waiting tasks step back,
# past dates in open tasks stand out, and lines changed outside get a mark
# in the margin. Size 20, so a line is 27 px high.
class TaskMarksTest < Minitest::Test
  STYLES = Shipinel::Styles.new(20.0)
  TODAY = "2026-11-08"

  def page(source, highlights: Shipinel::Highlights.none, width: 400.0)
    Shipinel::Layout.new(fake_font_set(source), STYLES, width).marking(highlights)
                    .arrange(Shipinel::Markdown::Parser.parse(source), [])
  end

  def commands(page) = Array.new(page.size) { |position| page.at(position) }
  def runs(page) = commands(page).grep(Shipinel::TextRun)
  def looks(page) = runs(page).map { |run| [run.text.strip, run.style.font_slot, run.style.color] }

  def marks(page)
    commands(page).select { |command| command.is_a?(Shipinel::Box) && command.color == Shipinel::Theme::Accent::CHANGED }
                  .map(&:rect)
  end

  # Italic and quieter; a done task stays muted even when marked waiting.
  def test_waiting_task_text_steps_back
    waiting = [Shipinel::Theme::FontSlot::ITALIC, Shipinel::Theme::Ink::WAITING]

    assert_equal [["ship", *waiting], ["(Waiting", *waiting], ["on", *waiting], ["Ana)", *waiting],
                  ["old", 0, Shipinel::Theme::Ink::MUTED], ["(waiting)", 0, Shipinel::Theme::Ink::MUTED],
                  ["go", 0, Shipinel::Theme::Ink::BODY]],
                 looks(page("- [ ] ship (Waiting on Ana)\n- [x] old (waiting)\n- [ ] go"))
  end

  def test_hourglass_marks_a_task_as_waiting
    assert Shipinel::Markdown::Task.waiting?("deploy ⏳")
    refute Shipinel::Markdown::Task.waiting?("waiting room tour")
  end

  # Only in open tasks: a done task, or a date in a paragraph, is history.
  def test_past_dates_in_open_tasks_are_overdue
    source = "- [ ] due 2026-11-07 or 2026-11-08\n- [x] 2026-11-01\n\n2026-11-01"
    colors = runs(page(source, highlights: Shipinel::Highlights.new(TODAY, Shipinel::LineChanges.none)))
             .to_h { |run| [run.text.strip, run.style.color] }

    assert_equal({ "due" => Shipinel::Theme::Ink::BODY, "2026-11-07" => Shipinel::Theme::Accent::OVERDUE,
                   "or" => Shipinel::Theme::Ink::BODY, "2026-11-08" => Shipinel::Theme::Ink::BODY,
                   "2026-11-01" => Shipinel::Theme::Ink::BODY }, colors)
  end

  # The paragraph was edited outside; at 200 px it wraps to two lines.
  def changed_paragraph_marks
    after = "# a\n\nnew text that wraps around\n"
    changes = Shipinel::LineChanges.between("# a\n\nold\n", after, 0)
    marks(page(after, highlights: Shipinel::Highlights.new("", changes), width: 200.0))
  end

  # One mark per text line of a changed block, in the left margin.
  def test_lines_changed_outside_are_marked_in_the_margin
    rects = changed_paragraph_marks
    sizes = rects.map { |rect| [rect.left, rect.width, rect.height] }

    assert_equal [[5.0, 3.0, 27.0]] * 2, sizes
    assert_operator rects.first.top, :<, rects.last.top
  end

  def test_nothing_changed_nothing_marked
    assert_empty marks(page("# a\n\ntext\n"))
  end
end
