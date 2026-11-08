# frozen_string_literal: true

# The user's settings, from ~/.config/shipinel/config (or $XDG_CONFIG_HOME):
# the plan to open when no path is given, notifications, and the tray. Every
# setting has a default, so the file is optional; a value that does not fit
# keeps the default and is reported (bin/shipinel.rb prints it).

require_relative "cli_options"
require_relative "key_values"

module Shipinel
  # When to show desktop notifications.
  class NotifySettings
    # Example match: "17:30".
    TIME_OF_DAY = /\A([01]\d|2[0-3]):[0-5]\d\z/

    # "HH:MM" for a daily nudge with the number of open tasks, "" for none.
    attr_reader :daily_at #: String

    # @rbs @save_failed: bool

    #: (String daily_at, bool save_failed) -> void
    def initialize(daily_at, save_failed)
      @daily_at = daily_at
      @save_failed = save_failed
    end

    # When ticking a box could not be saved.
    #: () -> bool
    def save_failed?
      @save_failed
    end
  end

  # Whether there is a tray icon, and whether closing the window only hides
  # it there.
  class TraySettings
    # @rbs @shown: bool
    # @rbs @close_to_tray: bool

    #: (bool shown, bool close_to_tray) -> void
    def initialize(shown, close_to_tray)
      @shown = shown
      @close_to_tray = close_to_tray
    end

    #: () -> bool
    def shown?
      @shown
    end

    # Only with a tray icon to bring the window back.
    #: () -> bool
    def close_to_tray?
      @shown && @close_to_tray
    end
  end

  # See the file comment.
  class Config
    attr_reader :notify #: NotifySettings
    attr_reader :tray #: TraySettings
    # One line per setting that kept its default because its value did not fit.
    attr_reader :problems #: Array[String]

    # @rbs @values: KeyValues

    #: (String text) -> void
    def initialize(text)
      @values = KeyValues.new(text)
      @problems = []
      @notify = NotifySettings.new(daily_at, switch("notify_save_failed", true))
      @tray = TraySettings.new(switch("tray", false), switch("close_to_tray", false))
    end

    # The words that turn a setting on. (Methods, not constants: Spinel
    # does not seed a constant's type, docs/spinel-notes.md.)
    #: () -> Array[String]
    def self.yes_words
      %w[on yes true 1]
    end

    #: () -> Array[String]
    def self.no_words
      %w[off no false 0]
    end

    # Whether a yes/no setting accepts the word.
    #: (String value) -> bool
    def self.switch_word?(value)
      yes_words.include?(value) || no_words.include?(value)
    end

    # The plan to open: the path given on the command line, else the
    # config's `file` (~ means the home directory).
    #: (String given, String config_path) -> String
    def plan(given, config_path)
      return given unless given.empty?

      file = @values["file"]
      raise UsageError, "missing PATH.md (or file= in #{config_path})\n#{CliOptions::USAGE}" if file.empty?

      File.expand_path(file)
    end

    private

    #: () -> String
    def daily_at
      value = @values["notify_daily"]
      return value if value.empty? || NotifySettings::TIME_OF_DAY.match?(value)

      reject("notify_daily", value, "a time like 17:30, or nothing")
    end

    #: (String key, bool default) -> bool
    def switch(key, default)
      value = @values[key].downcase
      return Config.yes_words.include?(value) if Config.switch_word?(value)

      reject(key, value, "on or off") unless value.empty?
      default
    end

    #: (String key, String value, String wanted) -> String
    def reject(key, value, wanted)
      @problems << "#{key}=#{value} is not #{wanted}; using the default"
      ""
    end
  end

  # Where the config is.
  module ConfigFile
    #: () -> String
    def self.path
      base = ENV.fetch("XDG_CONFIG_HOME", "")
      base = File.join(ENV.fetch("HOME", "/tmp"), ".config") if base.empty?
      File.join(base, "shipinel", "config")
    end

    # The settings, all defaults when the file is missing or unreadable.
    #: () -> Config
    def self.read
      Config.new(File.read(path))
    rescue SystemCallError
      Config.new("")
    end
  end
end
