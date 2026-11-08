# frozen_string_literal: true

# What Shipinel shows outside its window: notifications (Reminder) and the
# tray icon (TrayIcon), both as the config asks.

require_relative "reminder"
require_relative "tray_icon"

module Shipinel
  # See the file comment.
  class Desktop
    # @rbs @reminder: Reminder
    # @rbs @tray_icon: TrayIcon

    #: (Reminder reminder, TrayIcon tray_icon) -> void
    def initialize(reminder, tray_icon)
      @reminder = reminder
      @tray_icon = tray_icon
    end

    # The date of the last daily nudge, saved with the plan's state.
    #: () -> String
    def nudged
      @reminder.nudged
    end

    #: (String title) -> void
    def start(title)
      @tray_icon.start(Tray.new, title)
    end

    # Every chore: the daily nudge when it is time, and the tray's progress.
    #: (Markdown::BlockList blocks, String name) -> void
    def remind(blocks, name)
      @reminder.tick(WallTime.now, blocks, name)
      progress = blocks.task_progress
      @tray_icon.show(progress.tray_label, progress.share)
    end

    #: (String problem) -> void
    def save_failed(problem)
      @reminder.save_failed(problem)
    end

    # Acts on the tray's clicks; whether the window was shown again.
    #: () -> bool
    def reshown?
      @tray_icon.reshown?
    end

    # The tray's Quit, or the window's close button unless that hides it.
    #: (Screen screen) -> bool
    def ending?(screen)
      @tray_icon.ending?(screen)
    end
  end
end
