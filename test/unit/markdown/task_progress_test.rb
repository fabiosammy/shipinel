# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../../lib/shipinel/markdown/parser"

class TaskProgressTest < Minitest::Test
  def progress(source) = Shipinel::Markdown::Parser.parse(source).task_progress

  def test_counts_tasks_at_any_depth_but_not_in_code_fences
    found = progress("# Semana\n- [ ] a\n  - [x] b\n* [X] c\n1. [ ] d\n- item\n```\n- [x] não\n```\n")

    assert_equal [2, 4], [found.done, found.total]
  end

  def test_label_with_the_share_rounded_down
    assert_equal "2 of 3 tasks done · 66%", progress("- [x] a\n- [x] b\n- [ ] c\n").label
  end

  def test_one_task_is_singular
    assert_equal "0 of 1 task done · 0%", progress("- [ ] a\n").label
  end

  def test_complete_only_when_every_task_is_checked
    assert_equal [false, true, false],
                 [progress("- [x] a\n- [ ] b\n").complete?, progress("- [x] a\n").complete?, progress("").complete?]
  end

  def test_file_without_tasks_has_nothing_to_show
    found = progress("só texto\n")

    assert_equal [false, 0.0, 0], [found.tasks?, found.share, found.percent]
  end
end
