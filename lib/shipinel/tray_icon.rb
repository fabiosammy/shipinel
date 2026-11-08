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
    # @rbs @title: String
    # @rbs @quit: bool

    #: (TraySettings settings) -> void
    def initialize(settings)
      @tray = AbsentTray.new
      @settings = settings
      @title = ""
      @quit = false
    end

    # Opens `tray` when the config asks for an icon; it is used once a tray
    # host took it. The title is kept for an icon turned on later.
    #: (Tray tray, String title) -> void
    def start(tray, title)
      @title = title
      open_in(tray) if @settings.shown?
      nil
    end

    # The config changed: the icon is opened (in `tray`) or closed when
    # `tray=` changed, and close_to_tray follows the new settings.
    #: (TraySettings settings, Tray tray) -> void
    def use(settings, tray)
      turned = settings.shown? != @settings.shown?
      @settings = settings
      turn(tray) if turned
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
      return true unless hides_on_close?

      @tray.hide_window
      false
    end

    private

    # `tray=` changed: the icon comes (in `tray`) or goes.
    #: (Tray tray) -> void
    def turn(tray)
      @settings.shown? ? open_in(tray) : remove
    end

    #: (Tray tray) -> void
    def open_in(tray)
      if tray.open(@title)
        @tray = tray
      else
        warn "shipinel: no tray to show the icon in (on GNOME the AppIndicator extension adds one)"
      end
      nil
    end

    # The icon goes away; a window hidden in it is shown again first.
    #: () -> void
    def remove
      @tray.close
      @tray = AbsentTray.new
      nil
    end

    # Only with an icon to bring the window back.
    #: () -> bool
    def hides_on_close?
      @tray.open? && @settings.close_to_tray?
    end

    # Hides a shown window or shows a hidden one; whether it shows now.
    #: () -> bool
    def shown_after_toggle?
      @tray.toggle_window
      @tray.window_shown?
    end
  end
end
