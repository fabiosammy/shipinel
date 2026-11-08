# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/config"

class ConfigTest < Minitest::Test
  def config(text) = Shipinel::Config.new(text)

  # Daily time, save-failed notice, tray, close to tray.
  def summary(settings)
    notify = settings.notify
    tray = settings.tray
    [notify.daily_at, notify.save_failed?, tray.shown?, tray.close_to_tray?]
  end

  def test_defaults_without_a_file
    settings = config("")

    assert_equal [["", true, false, false], []], [summary(settings), settings.problems]
  end

  def test_every_setting
    text = "# mine\nfile = ~/notes/week.md\nnotify_daily=17:30\nnotify_save_failed=off\ntray=on\nclose_to_tray=yes\n"

    assert_equal ["17:30", false, true, true], summary(config(text))
  end

  def test_closing_to_the_tray_needs_the_tray
    refute_predicate config("close_to_tray=on\n").tray, :close_to_tray?
  end

  def test_values_that_do_not_fit_keep_the_default_and_are_reported
    settings = config("notify_daily=5pm\ntray=maybe\n")

    assert_equal ["", false], [settings.notify.daily_at, settings.tray.shown?]
    assert_equal ["notify_daily=5pm is not a time like 17:30, or nothing; using the default",
                  "tray=maybe is not on or off; using the default"], settings.problems
  end

  def test_the_command_line_path_wins_over_the_config
    assert_equal "a.md", config("file=/b.md\n").plan("a.md", "/c/config")
  end

  def test_the_config_file_with_home_expanded
    assert_equal File.join(Dir.home, "notes", "week.md"), config("file=~/notes/week.md\n").plan("", "/c/config")
  end

  def test_no_path_anywhere_is_a_usage_error
    error = assert_raises(Shipinel::UsageError) { config("").plan("", "/c/config") }

    assert_match(%r{missing PATH\.md \(or file= in /c/config\)}, error.message)
  end

  def test_config_file_location
    ENV["XDG_CONFIG_HOME"] = "/x/config"

    assert_equal "/x/config/shipinel/config", Shipinel::ConfigFile.path
  ensure
    ENV.delete("XDG_CONFIG_HOME")
  end

  def test_a_missing_config_reads_as_defaults
    ENV["XDG_CONFIG_HOME"] = "/nonexistent"

    assert_empty Shipinel::ConfigFile.read.problems
  ensure
    ENV.delete("XDG_CONFIG_HOME")
  end
end
