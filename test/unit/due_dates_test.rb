# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/due_dates"
require_relative "../../lib/shipinel/markdown/parser"

# On Sunday 2026-11-08: which open tasks are overdue or due today.
class DueDatesTest < Minitest::Test
  SUNDAY = Shipinel::Day.new("2026-11-08", 0)

  PLAN = <<~MARKDOWN
    - [ ] review (due 2026-11-06)
    - [ ] demo on 2026-11-07, then 2026-11-08
    - [ ] report 2026-11-08
    - [ ] retro 2026-11-12
    - [x] shipped 2026-11-01
    - [ ] no date

    Paragraph 2026-11-01
  MARKDOWN

  def dates(day = SUNDAY) = Shipinel::DueDates.of(Shipinel::Markdown::Parser.parse(PLAN), day)

  # A task's first date counts; done tasks and paragraphs never do.
  def test_counts_open_tasks_overdue_and_due_today
    assert_equal [2, 1], [dates.overdue, dates.today]
  end

  def test_the_tray_label_says_what_needs_attention
    assert_equal "1 of 6 tasks done · 16% · 2 overdue · 1 due today", dates.after("1 of 6 tasks done · 16%")
  end

  def test_nothing_due_leaves_the_label_alone
    assert_equal "1 of 6 tasks done · 16%", dates(Shipinel::Day.new("2026-11-01", 0)).after("1 of 6 tasks done · 16%")
  end
end
