# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/tray_icon"
require_relative "../../lib/shipinel/markdown/parser"

class TrayIconTest < Minitest::Test
  # A tray host that takes the icon (or not) and has these clicks queued.
  class FakeTray
    attr_reader :calls

    def initialize(opens: true, events: [])
      @opens = opens
      @events = events
      @shown = true
      @calls = []
    end

    def open(title) = (@calls << [:open, title]) && @opens
    def show_progress(label, share) = @calls << [:progress, label, share]
    def next_event = @events.shift || Shipinel::Tray::NONE
    def window_shown? = @shown
    def open? = true
    def close = (@calls << [:close]) && (@shown = true)

    def hide_window = (@calls << [:show_window, false]) && (@shown = false)

    def toggle_window
      @shown = !@shown
      @calls << [:show_window, @shown]
    end
  end

  def icon(tray, shown: true, close_to_tray: false)
    tray_icon = Shipinel::TrayIcon.new(Shipinel::TraySettings.new(shown, close_to_tray))
    tray_icon.start(tray, "Shipinel · week.md")
    tray_icon
  end

  def progress(source) = Shipinel::Markdown::Parser.parse(source).task_progress

  # The window's close button, pressed or not.
  Closing = Struct.new(:closing?)
  PRESSED = Closing.new(true)
  NOT_PRESSED = Closing.new(false)

  def test_off_in_the_config_does_nothing
    tray = FakeTray.new(events: [Shipinel::Tray::QUIT])
    off = icon(tray, shown: false)
    off.show("1 of 2 tasks done · 50%", 0.5)

    assert_equal [[], false, false, true], [tray.calls, off.reshown?, off.ending?(NOT_PRESSED), off.ending?(PRESSED)]
  end

  def test_shows_the_progress
    tray = FakeTray.new
    icon(tray).show("1 of 2 tasks done · 50%", 0.5)

    assert_equal [[:open, "Shipinel · week.md"], [:progress, "1 of 2 tasks done · 50%", 0.5]], tray.calls
  end

  def test_tray_label_says_when_there_are_no_tasks
    assert_equal ["1 of 2 tasks done · 50%", "No tasks in this plan"],
                 [progress("- [x] a\n- [ ] b\n").tray_label, progress("texto\n").tray_label]
  end

  def test_a_click_hides_then_shows_the_window
    tray = FakeTray.new(events: [Shipinel::Tray::TOGGLE, Shipinel::Tray::TOGGLE])
    on = icon(tray)

    assert_equal [false, true], [on.reshown?, on.reshown?]
    assert_equal [[:show_window, false], [:show_window, true]], tray.calls.drop(1)
  end

  def test_quit_from_the_menu_ends_the_app
    on = icon(FakeTray.new(events: [Shipinel::Tray::QUIT]))
    on.reshown?

    assert on.ending?(NOT_PRESSED)
  end

  def test_closing_hides_to_the_tray_when_asked
    tray = FakeTray.new
    on = icon(tray, close_to_tray: true)

    assert_equal [false, [:show_window, false]], [on.ending?(PRESSED), tray.calls.last]
  end

  def test_closing_quits_without_close_to_tray
    assert icon(FakeTray.new).ending?(PRESSED)
  end

  def test_without_a_tray_host_it_says_so_and_closing_quits
    tray = FakeTray.new(opens: false)
    lost = nil
    _out, err = capture_io { lost = icon(tray, close_to_tray: true) }

    assert_match(/no tray to show the icon in/, err)
    assert lost.ending?(PRESSED)
  end

  # Turned on in the config while running: the icon opens with the title
  # it started with; turned off: it closes, showing a hidden window first.
  def test_the_config_turns_the_icon_on_and_off
    later = FakeTray.new
    icon = icon(FakeTray.new, shown: false)
    icon.use(Shipinel::TraySettings.new(true, true), later)
    hides = icon.ending?(PRESSED)
    icon.use(Shipinel::TraySettings.new(false, true), FakeTray.new)

    assert_equal [false, [[:open, "Shipinel · week.md"], [:show_window, false], [:close]], true],
                 [hides, later.calls, icon.ending?(PRESSED)]
  end

  def test_close_to_tray_follows_the_config_without_reopening
    tray = FakeTray.new
    icon = icon(tray)
    icon.use(Shipinel::TraySettings.new(true, true), FakeTray.new)

    assert_equal [false, [[:open, "Shipinel · week.md"], [:show_window, false]]], [icon.ending?(PRESSED), tray.calls]
  end
end
