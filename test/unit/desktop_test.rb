# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_ui"
require_relative "../../lib/shipinel/desktop"

# The config read again while running: Desktop#follow_config.
class DesktopTest < Minitest::Test
  # Records what it would notify.
  class FakeNotifier
    attr_reader :shown

    def initialize = @shown = []
    def show(summary, body) = (@shown << [summary, body]) && ""
  end

  def setup
    Shipinel::UI.calls.clear
    @notifier = FakeNotifier.new
    reminder = Shipinel::Reminder.new(Shipinel::NotifySettings.new("", true), @notifier, "")
    tray_icon = Shipinel::TrayIcon.new(Shipinel::TraySettings.new(false, false))
    @desktop = Shipinel::Desktop.new(reminder, tray_icon, Shipinel::StopSignals.new, "")
    tray_icon.start(Shipinel::Tray.new, "Shipinel · week.md")
  end

  def test_an_unchanged_config_changes_nothing
    @desktop.follow_config("")

    assert_empty Shipinel::UI.calls
  end

  # tray=on opens the icon at once; notify_save_failed=off silences the
  # next failed save.
  def test_a_changed_config_applies_at_once
    @desktop.follow_config("tray=on\nnotify_save_failed=off\n")
    @desktop.save_failed("Cannot save /p/week.md: read-only file system")

    assert_equal [[[:tray_open, "Shipinel · week.md"]], []], [Shipinel::UI.calls, @notifier.shown]
  end

  def test_values_that_do_not_fit_are_reported
    _out, err = capture_io { @desktop.follow_config("tray=maybe\n") }

    assert_match(/tray=maybe is not on or off/, err)
  end
end
