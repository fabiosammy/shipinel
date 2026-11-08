# frozen_string_literal: true

# What runs beside the frames, about every 500 ms: the file poll's timing,
# and saving what the window should remember (SavedState) whenever it
# changed. Also what the window starts with: the state saved last time.

require_relative "poller"
require_relative "state_file"

module Shipinel
  # See the file comment.
  class Session
    attr_reader :saved #: SavedState

    # @rbs @file: StateFile
    # @rbs @poller: Poller
    # @rbs @written: String

    #: (StateFile file, SavedState saved, Integer now) -> void
    def initialize(file, saved, now)
      @file = file
      @saved = saved
      @poller = Poller.new(now)
      @written = saved.to_text
    end

    # The session for a plan: its saved state, or `start` and a window of
    # the given size for a plan never shown before.
    #: (String plan_path, View start, WindowPlace default_place) -> Session
    def self.for(plan_path, start, default_place)
      file = StateFile.for(plan_path)
      Session.new(file, StateReader.new(file.read).state(start, default_place), Clock.now_ms)
    end

    #: (Integer now) -> bool
    def due?(now)
      @poller.due?(now)
    end

    # Writes the state only when it differs from what was last written.
    #: (SavedState state) -> void
    def save(state)
      text = state.to_text
      return if text == @written

      @file.write(text)
      @written = text
    end
  end
end
