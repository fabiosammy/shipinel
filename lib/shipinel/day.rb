# frozen_string_literal: true

# A local day, and whether a heading of the plan is about it: today's
# heading is drawn in the accent color, and a new day opens there.

module Shipinel
  # A local day: its date ("2026-11-09") and weekday (0 is Sunday), and
  # whether a heading is about it.
  class Day
    # Example match: "a" in "Mondays", not "-" in "Segunda-feira".
    LETTER = /[[:alpha:]]/

    attr_reader :date #: String
    attr_reader :weekday #: Integer

    #: (String date, Integer weekday) -> void
    def initialize(date, weekday)
      @date = date
      @weekday = weekday
    end

    # No day: no heading is about it and no date is past.
    #: () -> Day
    def self.none
      Day.new("", -1)
    end

    #: () -> Day
    def self.today
      now = Time.now
      Day.new(now.strftime("%Y-%m-%d"), now.wday)
    end

    # Lowercase weekday names, Sunday first, in English and Portuguese
    # (a method, not a constant: Spinel does not type constants).
    #: () -> Array[String]
    def self.names
      %w[sunday monday tuesday wednesday thursday friday saturday
         domingo segunda terça quarta quinta sexta sábado]
    end

    # Whether `date` (YYYY-MM-DD) is an earlier day; never for "" or for
    # Day.none. ISO dates compare in time order as text.
    #: (String date) -> bool
    def later_than?(date)
      !date.empty? && !@date.empty? && date < @date
    end

    # A heading's plain title is about this day when it holds the date
    # ("Friday 2026-11-13 — housekeeping") or starts with the weekday's
    # name as a word ("Monday — push", "Segunda-feira").
    #: (String title) -> bool
    def heading?(title)
      return false if @date.empty?

      title.include?(@date) || named_in?(title.downcase)
    end

    #: (String title, String word) -> bool
    def self.starts_with_word?(title, word)
      title.start_with?(word) && !LETTER.match?(title[word.size, 1].to_s)
    end

    private

    #: (String title) -> bool
    def named_in?(title)
      names = Day.names
      Day.starts_with_word?(title, names[@weekday].to_s) || Day.starts_with_word?(title, names[@weekday + 7].to_s)
    end
  end
end
