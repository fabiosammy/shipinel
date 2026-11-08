# frozen_string_literal: true

# What the tray icon does, when the config turns it on: it shows the
# progress in its tooltip and ring, a click shows or hides the window, its
# menu's Quit ends the app, and with close_to_tray the window's close button
# hides the window instead of quitting. Without a tray host (GNOME without
# the AppIndicator extension) it says so once, and closing quits as usual,
# so the window can never be hidden with no way back.

require_relative "config"
require_relative "markdown/task_progress"
require_relative "screen"
require_relative "tray"

module Shipinel
  # See the file comment.
  class TrayIcon
    # @rbs @tray: Tray | AbsentTray
    # @rbs @settings: TraySettings
    # @rbs @hides_on_close: bool
    # @rbs @quit: bool

    #: (TraySettings settings) -> void
    def initialize(settings)
      @tray = AbsentTray.new
      @settings = settings
      @hides_on_close = false
      @quit = false
    end

    # Opens `tray` when the config asks for an icon; it is used once a tray
    # host took it.
    #: (Tray tray, String title) -> void
    def start(tray, title)
      return unless @settings.shown?

      if tray.open(title)
        @tray = tray
        @hides_on_close = @settings.close_to_tray?
      else
        warn "shipinel: no tray to show the icon in (on GNOME the AppIndicator extension adds one)"
      end
      nil
    end

    # The tooltip's text and the ring's share (0.0 to 1.0).
    #: (String label, Float share) -> void
    def show(label, share)
      @tray.show_progress(label, share)
    end

    # Acts on a click on the icon or its menu, and answers whether the
    # window was shown again (so its next frame is drawn in full).
    #: () -> bool
    def reshown?
      event = @tray.next_event
      @quit ||= event == Tray::QUIT
      event == Tray::TOGGLE && shown_after_toggle?
    end

    # Whether the app should end: the menu's Quit, or the window's close
    # button unless that only hides the window.
    #: (Screen screen) -> bool
    def ending?(screen)
      return true if @quit
      return false unless screen.closing?
      return true unless @hides_on_close

      @tray.hide_window
      false
    end

    private

    # Hides a shown window or shows a hidden one; whether it shows now.
    #: () -> bool
    def shown_after_toggle?
      @tray.toggle_window
      @tray.window_shown?
    end
  end
end
