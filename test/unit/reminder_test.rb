# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/reminder"
require_relative "../../lib/shipinel/markdown/parser"

class ReminderTest < Minitest::Test
  # Records what would be shown; answers like notify-send would.
  class FakeNotifier
    attr_reader :shown

    def initialize(answer = "") = (@shown = []) && (@answer = answer)

    def show(summary, body)
      @shown << [summary, body]
      @answer
    end
  end

  def setup
    @notifier = FakeNotifier.new
  end

  def reminder(daily: "17:30", save_failed: true, nudged: "")
    Shipinel::Reminder.new(Shipinel::NotifySettings.new(daily, save_failed), @notifier, nudged)
  end

  def blocks(source) = Shipinel::Markdown::Parser.parse(source)
  def at(time, date = "2026-11-08") = Shipinel::WallTime.new(date, time, 0.5)

  OPEN = "- [x] a\n- [ ] b\n- [ ] c\n"

  def test_nudges_once_a_day_at_or_after_the_time
    nudger = reminder
    ["17:29", "17:30", "18:00"].each { |time| nudger.tick(at(time), blocks(OPEN), "week.md") }
    nudger.tick(at("17:31", "2026-11-09"), blocks(OPEN), "week.md")

    assert_equal [["2 tasks still open", "week.md · 33% done\nStill open: b"]] * 2, @notifier.shown
  end

  # Waiting tasks are skipped, and the example is shown without markup.
  def test_names_an_open_task_that_is_not_waiting
    reminder.tick(at("17:30"), blocks("- [ ] a ⏳\n- [ ] b (waiting on Ana)\n- [ ] **ship** [it](x)\n"), "week.md")

    assert_equal "week.md · 0% done\nStill open: ship it", @notifier.shown.first.last
  end

  def test_only_the_count_when_every_open_task_waits
    reminder.tick(at("17:30"), blocks("- [ ] a ⏳\n"), "week.md")

    assert_equal "week.md · 0% done", @notifier.shown.first.last
  end

  def test_one_open_task_is_singular
    reminder.tick(at("17:30"), blocks("- [ ] a\n"), "week.md")

    assert_equal "1 task still open", @notifier.shown.first.first
  end

  def test_no_nudge_when_everything_is_done_but_the_day_counts
    nudger = reminder
    nudger.tick(at("17:30"), blocks("- [x] a\n"), "week.md")

    assert_equal [[], "2026-11-08"], [@notifier.shown, nudger.nudged]
  end

  def test_no_nudge_after_a_restart_the_same_day
    reminder(nudged: "2026-11-08").tick(at("19:00"), blocks(OPEN), "week.md")

    assert_empty @notifier.shown
  end

  def test_no_daily_time_no_nudge
    reminder(daily: "").tick(at("23:59"), blocks(OPEN), "week.md")

    assert_empty @notifier.shown
  end

  def test_a_failed_save_is_told_when_wanted
    reminder.save_failed("Cannot save /p/week.md: read-only file system")
    reminder.save_failed("")
    reminder(save_failed: false).save_failed("Cannot save")

    assert_equal [["Shipinel could not save", "Cannot save /p/week.md: read-only file system"]], @notifier.shown
  end

  def test_a_notification_that_cannot_be_shown_is_printed
    @notifier = FakeNotifier.new("Could not run notify-send")

    assert_output(nil, "shipinel: Could not run notify-send\n") { reminder.save_failed("Cannot save") }
  end

  def test_notifier_runs_its_command
    assert_equal ["", "Could not run false to show \"x\" (is libnotify installed?)"],
                 [Shipinel::Notifier.new("true").show("x", "y"), Shipinel::Notifier.new("false").show("x", "y")]
  end

  def test_wall_time_now_has_a_date_and_a_time
    now = Shipinel::WallTime.now

    assert_match(/\A\d{4}-\d\d-\d\d \d\d:\d\d\z/, "#{now.date} #{now.time}")
    assert_includes 0.0..1.0, now.week_share
  end

  # The config changed: no daily time now, so no nudge.
  def test_new_settings_apply_from_now_on
    nudger = reminder
    nudger.use(Shipinel::NotifySettings.new("", true))
    nudger.tick(at("18:00"), blocks(OPEN), "week.md")

    assert_empty @notifier.shown
  end
end
