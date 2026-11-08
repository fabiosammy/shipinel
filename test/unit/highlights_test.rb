# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/highlighter"
require_relative "../../lib/shipinel/markdown/parser"

class HighlightsTest < Minitest::Test
  SUNDAY = Shipinel::Day.new("2026-11-08", 0)
  MONDAY = Shipinel::Day.new("2026-11-09", 1)

  def changes(before, after) = Shipinel::LineChanges.between(before, after, 1_000)

  def test_changed_and_added_lines_are_marked_moved_ones_are_not
    assert_equal [1, 3], changes("a\nb\nc\n", "c\nB\na\nd\n").lines
  end

  def test_line_endings_do_not_count_as_changes
    assert_empty changes("a\r\nb", "a\nb\n").lines
  end

  def test_a_file_that_appears_marks_nothing
    assert_empty changes("", "- [ ] new\n").lines
  end

  # "b" was removed before "c" (now line 2); "e" from the end (line 4 is
  # past the last line). The blank line neither ends nor places a run.
  def test_removed_lines_are_placed_before_the_line_that_follows_them
    assert_equal [2, 4], changes("a\nb\n\nc\nd\ne\n", "a\n\nc\nd\n").removed
  end

  def test_only_removed_lines_still_expire
    removed = changes("a\nb\n", "a\n")

    assert_equal [true, false, true], [removed.lines.empty?, removed.expired?(10_999), removed.expired?(11_000)]
  end

  def test_marks_expire_after_ten_seconds
    marked = changes("a\n", "b\n")

    refute marked.expired?(10_999)
    assert marked.expired?(11_000)
    refute Shipinel::LineChanges.none.expired?(99_000)
  end

  def test_a_block_is_changed_when_any_of_its_lines_is
    highlights = Shipinel::Highlights.new(Shipinel::Day.none, changes("a\nb\nc\n", "a\nb\nC\n"))

    assert highlights.changed?(1, 2)
    refute highlights.changed?(0, 1)
  end

  def test_dates_before_today_are_overdue
    highlights = Shipinel::Highlights.new(SUNDAY, Shipinel::LineChanges.none)

    assert highlights.overdue?("(2026-11-07)")
    refute highlights.overdue?("2026-11-08")
    refute highlights.overdue?("Monday")
  end

  def test_no_date_known_nothing_is_overdue
    refute Shipinel::Highlights.none.overdue?("1999-01-01")
  end

  def poll_marks(highlighter, after, now)
    highlighter.poll("- [ ] a\n", after, now)
    highlighter.highlights.changes.lines
  end

  # Marked on the poll that sees the edit, kept on the next ones while
  # nothing changes, gone after ten seconds.
  def test_highlighter_keeps_the_marks_for_a_while
    highlighter = Shipinel::Highlighter.new(SUNDAY)
    after = "- [ ] a\n- [ ] b\n"

    assert_equal [[1], [1], []],
                 [poll_marks(highlighter, after, 1_000), poll_marks(highlighter, "- [ ] a\n", 5_000),
                  poll_marks(highlighter, "- [ ] a\n", 11_000)]
  end

  def test_highlighter_moves_the_date_on_and_says_when_it_is_a_new_day
    highlighter = Shipinel::Highlighter.new(SUNDAY)

    assert_equal [false, true, "2026-11-09"],
                 [highlighter.turned_to?(SUNDAY), highlighter.turned_to?(MONDAY), highlighter.highlights.today]
  end

  # The window was open over midnight: the next poll goes to today's
  # heading, the ones after stay put.
  def test_after_midnight_the_page_goes_to_todays_heading
    today = Shipinel::Day.today
    blocks = Shipinel::Markdown::Parser.parse("# Week\n## Plan for #{today.date}\n")
    highlighter = Shipinel::Highlighter.new(SUNDAY.date == today.date ? MONDAY : SUNDAY)

    assert_equal ["plan-for-#{today.date}", false],
                 [highlighter.reloaded("", "", blocks).slug, highlighter.reloaded("", "", blocks).aimed?]
  end

  def test_a_heading_holding_the_date_is_about_the_day
    assert MONDAY.heading?("Runbook — week of 2026-11-09 → 2026-11-13")
    refute MONDAY.heading?("Goal 1 — 2026-11-10")
  end

  # English or Portuguese, as the first word; not inside a longer word.
  def test_a_heading_starting_with_the_weekday_is_about_the_day
    assert MONDAY.heading?("Monday — push what is written")
    assert MONDAY.heading?("Segunda-feira")
    refute SUNDAY.heading?("Monday")
  end

  def test_the_weekday_must_be_the_first_whole_word
    refute MONDAY.heading?("Mondays are slow")
    refute MONDAY.heading?("Goal 1 — Monday demo")
  end

  def test_no_day_no_heading
    refute Shipinel::Day.none.heading?("Monday")
  end

  def test_same_date_and_marks_fit_the_same_layout
    marked = changes("a\n", "b\n")
    today = Shipinel::Highlights.new(SUNDAY, marked)

    assert today.same_as?(Shipinel::Highlights.new(SUNDAY, changes("a\n", "b\n")))
    refute today.same_as?(Shipinel::Highlights.new(MONDAY, marked))
    refute today.same_as?(Shipinel::Highlights.new(SUNDAY, Shipinel::LineChanges.none))
  end
end
