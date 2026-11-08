# frozen_string_literal: true

# The tray icon and the window's visibility, as the rest of the app sees
# them: Ruby names over the FFI calls into ext/tray.c and the shim. Stateless
# like Screen: the icon's state lives in C (.reek.yml).

module Shipinel
  # See the file comment.
  class Tray
    # What #next_event answers (ext/tray.h).
    NONE = 0
    TOGGLE = 1
    QUIT = 2

    # Whether a tray host took the icon.
    #: (String title) -> bool
    def open(title)
      UI.tray_open(title)
    end

    # The tooltip's text and the ring on the icon (`share` from 0.0 to 1.0).
    #: (String label, Float share) -> void
    def show_progress(label, share)
      UI.tray_show_progress(label, (share * 1000).round)
    end

    # The last click on the icon or its menu: NONE, TOGGLE or QUIT.
    #: () -> Integer
    def next_event
      UI.tray_next_event
    end

    # Unmapped; the icon brings it back.
    #: () -> void
    def hide_window
      UI.ui_show_window(0)
    end

    #: () -> bool
    def window_shown?
      UI.ui_window_shown
    end

    # Hides a shown window, shows a hidden one.
    #: () -> void
    def toggle_window
      UI.ui_show_window(window_shown? ? 0 : 1)
    end
  end

  # The tray when there is none: the config turned it off, or no tray host
  # took the icon. Every call does nothing, and the window always shows.
  class AbsentTray
    #: (String _label, Float _share) -> void
    def show_progress(_label, _share)
      nil
    end

    #: () -> Integer
    def next_event
      Tray::NONE
    end

    #: () -> void
    def hide_window
      nil
    end

    #: () -> bool
    def window_shown?
      true
    end

    # Never hidden.
    #: () -> void
    def toggle_window
      nil
    end
  end
end
