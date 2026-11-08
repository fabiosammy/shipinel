# frozen_string_literal: true

# What Shipinel shows outside its window and hears from outside it:
# notifications (Reminder) and the tray icon (TrayIcon), both as the config
# asks, and the signals that ask it to stop (StopSignals). The config file is
# read again on every chore: a change applies at once, except `file=`,
# which picks the plan at the next start.

require_relative "config"
require_relative "reminder"
require_relative "stop_signals"
require_relative "tray_icon"

module Shipinel
  # See the file comment.
  class Desktop
    # @rbs @reminder: Reminder
    # @rbs @tray_icon: TrayIcon
    # @rbs @signals: StopSignals
    # @rbs @config_text: String

    # `config_text`: the config file's text the settings came from.
    #: (Reminder reminder, TrayIcon tray_icon, StopSignals signals, String config_text) -> void
    def initialize(reminder, tray_icon, signals, config_text)
      @reminder = reminder
      @tray_icon = tray_icon
      @signals = signals
      @config_text = config_text
    end

    # The date of the last daily nudge, saved with the plan's state.
    # The desktop for `config`, with the day of the last nudge.
    #: (Config config, String nudged) -> Desktop
    def self.for(config, nudged)
      reminder = Reminder.new(config.notify, Notifier.new(Notifier::COMMAND), nudged)
      Desktop.new(reminder, TrayIcon.new(config.tray), StopSignals.new, ConfigFile.text)
    end

    #: () -> String
    def nudged
      @reminder.nudged
    end

    #: (String title) -> void
    def start(title)
      @signals.watch
      @tray_icon.start(Tray.new, title)
    end

    # Every chore: the daily nudge when it is time, and the tray's progress.
    #: (Markdown::BlockList blocks, String name) -> void
    def remind(blocks, name)
      follow_config(ConfigFile.text)
      @reminder.tick(WallTime.now, blocks, name)
      progress = blocks.task_progress
      @tray_icon.show(progress.tray_label, progress.share)
    end

    #: (String problem) -> void
    def save_failed(problem)
      @reminder.save_failed(problem)
    end

    # Applies the config file's `text` when it changed since the last look,
    # and reports its values that do not fit, as at the start.
    #: (String text) -> void
    def follow_config(text)
      return if text == @config_text

      @config_text = text
      apply(Config.new(text))
    end

    #: (Config config) -> void
    def apply(config)
      config.problems.each { |problem| warn "shipinel: #{ConfigFile.path}: #{problem}" }
      @reminder.use(config.notify)
      @tray_icon.use(config.tray, Tray.new)
    end

    # Acts on the tray's clicks; whether the window was shown again.
    #: () -> bool
    def reshown?
      @tray_icon.reshown?
    end

    # A stop signal, the tray's Quit, or the window's close button unless
    # that hides it.
    #: (Screen screen) -> bool
    def ending?(screen)
      @signals.received? || @tray_icon.ending?(screen)
    end
  end
end
