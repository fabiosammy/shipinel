# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/session"
require "fileutils"

class SavedStateTest < Minitest::Test
  TODAY = Shipinel::Day.today.date
  START = Shipinel::View.starting_at(20)
  DEFAULT_PLACE = Shipinel::WindowPlace.sized(440, 640)

  def setup
    @dir = Dir.mktmpdir("shipinel-state")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def state(placed:)
    place = Shipinel::WindowPlace.new(Shipinel::Rect.new(30.0, 40.0, 500.0, 700.0), placed)
    Shipinel::SavedState.new(Shipinel::ScrollSpot.new("goal-1", 12.5, 300.0), Shipinel::View.new(24, 20, false), place,
                             Shipinel::StateDays.new("2026-11-08", "2026-11-09"))
  end

  def read(text) = Shipinel::StateReader.new(text).state(Shipinel::SavedState.fresh(START, DEFAULT_PLACE))

  def test_text_lists_every_field
    assert_equal "section=goal-1\nwithin=12.5\noffset=300.0\nsize=24\nheader=0\nwidth=500\nheight=700\nx=30\ny=40\n" \
                 "nudged=2026-11-08\nday=2026-11-09\n", state(placed: true).to_text
  end

  def test_no_position_where_the_window_system_places_windows
    refute_includes state(placed: false).to_text, "x="
  end

  def test_reads_back_the_day_it_was_saved
    assert_equal ["2026-11-09", ""], [read(state(placed: true).to_text).days.seen, read("").days.seen]
  end

  def test_reads_back_the_spot
    spot = read(state(placed: true).to_text).spot

    assert_equal ["goal-1", 12.5, 300.0], [spot.slug, spot.within, spot.offset]
  end

  def test_reads_back_the_view_keeping_the_starting_size
    view = read(state(placed: true).to_text).view

    assert_equal [24, 20, false], [view.size, view.start_size, view.header?]
  end

  def test_reads_back_the_window
    place = read(state(placed: true).to_text).place
    rect = place.rect

    assert_equal [30.0, 40.0, 500.0, 700.0, true], [rect.left, rect.top, rect.width, rect.height, place.placed?]
  end

  def test_nothing_saved_gives_the_defaults
    fresh = read("")

    assert_equal [false, 20, true, DEFAULT_PLACE], [fresh.spot.aimed?, fresh.view.size, fresh.view.header?, fresh.place]
  end

  def test_unusable_values_fall_back
    odd = read("size=500\nwidth=-3\nheight=abc\nnot a line\n")

    assert_equal [20, DEFAULT_PLACE], [odd.view.size, odd.place]
  end

  def test_state_file_is_named_after_the_plan_under_the_state_home
    file = Shipinel::StateFile.for("/home/ana/notes/week.md")

    assert_equal File.join(ENV.fetch("XDG_STATE_HOME"), "shipinel", "%home%ana%notes%week.md"), file.path
  end

  def test_write_makes_the_directories_and_read_gets_it_back
    file = Shipinel::StateFile.new(File.join(@dir, "a", "b", "state"))
    file.write("size=22\n")

    assert_equal ["size=22\n", false], [file.read, File.exist?("#{file.path}.tmp")]
  end

  def test_a_state_that_cannot_be_written_is_skipped
    blocker = File.join(@dir, "file")
    File.write(blocker, "")
    file = Shipinel::StateFile.new(File.join(blocker, "state"))
    file.write("size=22\n")

    assert_equal "", file.read
  end

  def test_reads_back_the_last_nudge
    assert_equal ["2026-11-08", ""], [read(state(placed: false).to_text).days.nudged, read("").days.nudged]
  end

  def session(file)
    reminder = Shipinel::Reminder.new(Shipinel::NotifySettings.new("", false), Shipinel::Notifier.new("false"), "")
    tray_icon = Shipinel::TrayIcon.new(Shipinel::TraySettings.new(false, false))
    Shipinel::Session.new(file, read("day=#{TODAY}\n"), Shipinel::Desktop.new(reminder, tray_icon))
  end

  def save(session, state) = session.save(state.spot, state.view, state.place)

  # The session's reminder never nudged, so the saved text has "nudged=";
  # the session saves today as its day.
  def expected_after_save
    state(placed: false).to_text.sub("nudged=2026-11-08", "nudged=").sub("day=2026-11-09", "day=#{TODAY}")
  end

  def test_session_writes_only_when_the_state_changed
    file = Shipinel::StateFile.new(File.join(@dir, "state"))
    keeper = session(file)
    save(keeper, read(""))
    unchanged = File.exist?(file.path)
    save(keeper, state(placed: false))

    assert_equal [false, expected_after_save], [unchanged, file.read]
  end
end
