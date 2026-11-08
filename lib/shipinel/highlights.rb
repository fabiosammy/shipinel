# frozen_string_literal: true

# What the page points out beyond the Markdown itself: today's section,
# dates in open tasks that are already past, and the lines an edit outside
# Shipinel just changed (marked beside the text for a few seconds, so the
# change is noticed).

require_relative "day"
require_relative "line_changes"

module Shipinel
  # See the file comment: today (Day.none to point out no day or dates) and
  # the lines just changed outside.
  class Highlights
    # Example match: "2026-11-05" in "(due 2026-11-05)"
    DATE = /(?<date>\d{4}-\d{2}-\d{2})/

    attr_reader :day #: Day
    attr_reader :changes #: LineChanges

    #: (Day day, LineChanges changes) -> void
    def initialize(day, changes)
      @day = day
      @changes = changes
    end

    #: () -> Highlights
    def self.none
      Highlights.new(Day.none, LineChanges.none)
    end

    # Today's date, "" for none.
    #: () -> String
    def today
      @day.date
    end

    # A word holding a date before today. ISO dates compare in time order
    # as text.
    #: (String word) -> bool
    def overdue?(word)
      match = DATE.match(word)
      return false unless match

      today = @day.date
      !today.empty? && match[:date].to_s < today
    end

    # Whether a block on lines first..last was changed outside.
    #: (Integer first, Integer last) -> bool
    def changed?(first, last)
      @changes.within?(first, last)
    end

    # Whether lines removed outside were just before this block.
    #: (Integer first, Integer last) -> bool
    def removed_before?(first, last)
      @changes.removed_within?(first, last)
    end

    # Same dates and the same marks: the page laid out for one fits the
    # other.
    #: (Highlights other) -> bool
    def same_as?(other)
      other_changes = other.changes
      today == other.today && @changes.lines == other_changes.lines && @changes.removed == other_changes.removed
    end
  end
end
