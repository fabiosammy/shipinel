# frozen_string_literal: true

# Desktop notifications, sent with notify-send (libnotify; the Nix package
# puts it on PATH). Shown by whatever notification daemon the desktop runs.

module Shipinel
  # See the file comment. The command is injected so tests never notify.
  class Notifier
    COMMAND = "notify-send"

    # @rbs @command: String

    #: (String command) -> void
    def initialize(command)
      @command = command
    end

    # Returns "" when it was handed over, or why not (printed on stderr by
    # Reminder: there is no window notice for a notification).
    #: (String summary, String body) -> String
    def show(summary, body)
      return "" if system(@command, "--app-name=shipinel", summary, body)

      "Could not run #{@command} to show \"#{summary}\" (is libnotify installed?)"
    end
  end
end
