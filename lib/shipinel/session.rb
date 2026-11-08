# frozen_string_literal: true

# What runs beside the frames: the file poll's timing (about every 500 ms),
# saving what the window should remember (SavedState) whenever it changed,
# and what shows outside the window (Desktop: notifications and the tray
# icon). Also what the window starts with: the state saved last time.

require_relative "config"
require_relative "desktop"
require_relative "day"
require_relative "poller"
require_relative "state_file"

module Shipinel
  # See the file comment.
  class Session
    # The state last saved, or read at the start.
    attr_reader :saved #: SavedState
    # Notifications and the tray icon.
    attr_reader :desktop #: Desktop

    # @rbs @file: StateFile
    # @rbs @poller: Poller

    #: (StateFile file, SavedState saved, Desktop desktop) -> void
    def initialize(file, saved, desktop)
      @file = file
      @saved = saved
      @desktop = desktop
      @poller = Poller.new(Clock.now_ms)
    end

    # The session for a plan: its saved state, or `defaults` for a plan
    # never shown before, with notifications and a tray as `config` says.
    #: (String plan_path, SavedState defaults, Config config) -> Session
    def self.for(plan_path, defaults, config)
      file = StateFile.for(plan_path)
      saved = StateReader.new(file.read).state(defaults)
      Session.new(file, saved, Desktop.for(config, saved.days.nudged))
    end

    #: (Integer now) -> bool
    def due?(now)
      @poller.due?(now)
    end

    # Writes the state only when it differs from what was last written.
    #: (ScrollSpot spot, View view, WindowPlace place) -> void
    def save(spot, view, place)
      state = SavedState.new(spot, view, place, StateDays.new(@desktop.nudged, Day.today.date))
      text = state.to_text
      return if text == @saved.to_text

      @file.write(text)
      @saved = state
    end
  end
end
