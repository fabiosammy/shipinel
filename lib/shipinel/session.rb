# frozen_string_literal: true

# What runs beside the frames, about every 500 ms: the file poll's timing,
# saving what the window should remember (SavedState) whenever it changed,
# and the notifications (Reminder). Also what the window starts with: the
# state saved last time.

require_relative "poller"
require_relative "reminder"
require_relative "state_file"

module Shipinel
  # See the file comment.
  class Session
    # The state last saved, or read at the start.
    attr_reader :saved #: SavedState

    # @rbs @file: StateFile
    # @rbs @poller: Poller
    # @rbs @reminder: Reminder

    #: (StateFile file, SavedState saved, Reminder reminder) -> void
    def initialize(file, saved, reminder)
      @file = file
      @saved = saved
      @reminder = reminder
      @poller = Poller.new(Clock.now_ms)
    end

    # The session for a plan: its saved state, or `defaults` for a plan
    # never shown before, and notifications as `notify` says.
    #: (String plan_path, SavedState defaults, NotifySettings notify) -> Session
    def self.for(plan_path, defaults, notify)
      file = StateFile.for(plan_path)
      saved = StateReader.new(file.read).state(defaults)
      Session.new(file, saved, Reminder.new(notify, Notifier.new(Notifier::COMMAND), saved.nudged))
    end

    #: (Integer now) -> bool
    def due?(now)
      @poller.due?(now)
    end

    # Writes the state only when it differs from what was last written.
    #: (ScrollSpot spot, View view, WindowPlace place) -> void
    def save(spot, view, place)
      state = SavedState.new(spot, view, place, @reminder.nudged)
      text = state.to_text
      return if text == @saved.to_text

      @file.write(text)
      @saved = state
    end

    # The daily nudge, when it is time.
    #: (Markdown::TaskProgress progress, String name) -> void
    def remind(progress, name)
      @reminder.tick(WallTime.now, progress, name)
    end

    # After a click on a checkbox: `problem` is "" when it was saved.
    #: (String problem) -> void
    def save_failed(problem)
      @reminder.save_failed(problem)
    end
  end
end
