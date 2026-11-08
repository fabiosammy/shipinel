# frozen_string_literal: true

# The local wall clock, as Shipinel uses it: the date and time of day for
# the daily nudge, and how far through the work week it is for the pace.

require_relative "week_progress"

module Shipinel
  # The local date and time of day ("2026-11-08", "17:30"), and how far
  # through the work week that is (WeekProgress).
  class WallTime
    attr_reader :date #: String
    attr_reader :time #: String
    attr_reader :week_share #: Float

    #: (String date, String time, Float week_share) -> void
    def initialize(date, time, week_share)
      @date = date
      @time = time
      @week_share = week_share
    end

    #: () -> WallTime
    def self.now
      now = Time.now
      WallTime.new(now.strftime("%Y-%m-%d"), now.strftime("%H:%M"),
                   WeekProgress.expected_at(now.wday, (now.hour * 60) + now.min))
    end
  end
end
