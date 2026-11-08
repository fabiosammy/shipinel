# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_ui"
require_relative "../../lib/shipinel/tray"

class TrayTest < Minitest::Test
  def setup
    Shipinel::UI.calls.clear
    @tray = Shipinel::Tray.new
  end

  def test_calls_into_the_shim
    answers = [@tray.open("Shipinel · week.md"), @tray.next_event, @tray.window_shown?]
    @tray.show_progress("1 of 3 tasks done · 33%", 1.0 / 3)
    @tray.hide_window
    @tray.toggle_window

    assert_equal [true, Shipinel::Tray::TOGGLE, true], answers
    assert_equal [[:tray_open, "Shipinel · week.md"], [:tray_event], [:window_shown],
                  [:tray_progress, "1 of 3 tasks done · 33%", 333], [:show_window, 0], [:window_shown],
                  [:show_window, 0]], Shipinel::UI.calls
  end

  def test_absent_tray_does_nothing_and_the_window_shows
    absent = Shipinel::AbsentTray.new
    absent.show_progress("x", 0.5)
    absent.hide_window

    absent.toggle_window

    assert_equal [Shipinel::Tray::NONE, true, []], [absent.next_event, absent.window_shown?, Shipinel::UI.calls]
  end
end
