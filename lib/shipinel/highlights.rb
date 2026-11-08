# frozen_string_literal: true

# What the page points out beyond the Markdown itself: today's section,
# dates in open tasks that are already past, and the lines an edit outside
# Shipinel just changed (marked beside the text for a few seconds, so the
# change is noticed).

require_relative "day"
require_relative "line_changes"

module Shipinel
  # A word cut around the past date it holds: what comes before, the date,
  # and what comes after ("(", "2026-11-07", ")."). A word without one is
  # all `before`, with an empty date.
  class DatedWord
    attr_reader :before #: String
    attr_reader :date #: String
    attr_reader :after #: String

    #: (String before, String date, String after) -> void
    def initialize(before, date, after)
      @before = before
      @date = date
      @after = after
    end

    #: (String word) -> DatedWord
    def self.plain(word)
      DatedWord.new(word, "", "")
    end

    # `word` cut around `date` ("" for none).
    #: (String word, String date) -> DatedWord
    def self.around(word, date)
      return DatedWord.plain(word) if date.empty?

      parts = word.split(date, 2)
      DatedWord.new(parts[0].to_s, date, parts[1].to_s)
    end
  end

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

    # A word cut around the date before today it holds ("2026-11-07" in
    # "(2026-11-07)."), if any.
    #: (String word) -> DatedWord
    def overdue_parts(word)
      date = Highlights.date_in(word)
      DatedWord.around(word, @day.later_than?(date) ? date : "")
    end

    # The first YYYY-MM-DD in a word, or "".
    #: (String word) -> String
    def self.date_in(word)
      match = DATE.match(word)
      match ? match[:date].to_s : ""
    end

    # Whether a block on lines first..last was changed outside.
    #: (Integer first, Integer last) -> bool
    def changed?(first, last)
      @changes.within?(first, last)
    end

    # Same dates and the same marks: the page laid out for one fits the
    # other.
    #: (Highlights other) -> bool
    def same_as?(other)
      today == other.today && @changes.lines == other.changes.lines
    end
  end
end
