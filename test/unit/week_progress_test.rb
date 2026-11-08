# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/week_progress"
require_relative "../../lib/shipinel/markdown/parser"

class WeekProgressTest < Minitest::Test
  # Monday 00:00, Wednesday noon, Friday 24:00, Saturday, Sunday.
  def test_week_share_from_monday_to_friday
    shares = [[1, 0], [3, 720], [5, 1440], [6, 600], [0, 600]].map do |weekday, minutes|
      Shipinel::WeekProgress.expected_at(weekday, minutes)
    end

    assert_equal [0.0, 0.5, 1.0, 1.0, 1.0], shares
  end

  def week(source, expected)
    Shipinel::WeekProgress.new(Shipinel::Markdown::Parser.parse(source).task_progress, expected)
  end

  def test_behind_means_more_than_a_workday_short
    half = "- [x] a\n- [ ] b\n"

    assert_equal [false, false, true], [week(half, 0.5).behind?, week(half, 0.7).behind?, week(half, 0.71).behind?]
  end

  def test_done_is_green_even_when_late
    assert_equal Shipinel::Theme::Progress::COMPLETE, week("- [x] a\n", 1.0).color
  end
end
