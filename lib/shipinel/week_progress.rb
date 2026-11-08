# frozen_string_literal: true

# The plan's progress against the work week: how far through its tasks it
# is, and how far it should be by now, if the tasks were spread evenly from
# Monday 00:00 to Friday 24:00 (at the weekend the week is over: all of
# them). More than a workday's share behind is "behind": the header's bar
# turns amber, with a tick where the week is.

require_relative "markdown/task_progress"
require_relative "theme"

module Shipinel
  # See the file comment.
  class WeekProgress
    WORKDAYS = 5
    MINUTES_PER_DAY = 1440.0

    # The share of the tasks that should be done by now, 0.0 to 1.0.
    attr_reader :expected #: Float

    # @rbs @progress: Markdown::TaskProgress

    #: (Markdown::TaskProgress progress, Float expected) -> void
    def initialize(progress, expected)
      @progress = progress
      @expected = expected
    end

    # The week's share gone by: `weekday` as Time#wday (0 Sunday, 1 Monday,
    # ... 6 Saturday), `minutes` since midnight.
    #: (Integer weekday, Integer minutes) -> Float
    def self.expected_at(weekday, minutes)
      return 1.0 if weekday.zero? || weekday > WORKDAYS

      (weekday - 1 + (minutes / MINUTES_PER_DAY)) / WORKDAYS
    end

    #: () -> bool
    def tasks?
      @progress.tasks?
    end

    #: () -> String
    def label
      @progress.label
    end

    #: () -> Float
    def share
      @progress.share
    end

    # The bar's color: green when done, amber when behind, blue otherwise.
    #: () -> Integer
    def color
      return Theme::Progress::COMPLETE if @progress.complete?

      behind? ? Theme::Pace::BEHIND : Theme::Progress::FILL
    end

    # More than one workday's share of the tasks behind the week.
    #: () -> bool
    def behind?
      share < @expected - (1.0 / WORKDAYS)
    end
  end
end
