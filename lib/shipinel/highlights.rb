# frozen_string_literal: true

# What the page points out beyond the Markdown itself: today's section,
# dates in open tasks that are already past or are today, and the lines an
# edit outside Shipinel just changed (marked beside the text for a few
# seconds, so the change is noticed).

require_relative "day"
require_relative "line_changes"
require_relative "theme"

module Shipinel
  # A word cut around the date it holds that is pointed out: what comes
  # before, the date, and what comes after ("(", "2026-11-07", ")."), with
  # the date's color. A word without one is all `before`, with an empty date.
  class DatedWord
    attr_reader :before #: String
    attr_reader :date #: String
    attr_reader :after #: String
    # Overdue (past) or due today (Highlights#color_of); 0 without a date.
    attr_reader :color #: Integer

    #: (String before, String date, String after, Integer color) -> void
    def initialize(before, date, after, color)
      @before = before
      @date = date
      @after = after
      @color = color
    end

    #: (String word) -> DatedWord
    def self.plain(word)
      DatedWord.new(word, "", "", 0)
    end

    # `word` cut around `date` in `color` (0 for none: not pointed out).
    #: (String word, String date, Integer color) -> DatedWord
    def self.around(word, date, color)
      return DatedWord.plain(word) if color.zero?

      parts = word.split(date, 2)
      DatedWord.new(parts[0].to_s, date, parts[1].to_s, color)
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

    # A word cut around the date it holds ("2026-11-07" in "(2026-11-07).")
    # when that is before today or today.
    #: (String word) -> DatedWord
    def dated_parts(word)
      date = Highlights.date_in(word)
      DatedWord.around(word, date, color_of(date))
    end

    # A date before today is overdue (amber); today's is due (the accent
    # of today's heading); any other gets 0, not pointed out.
    #: (String date) -> Integer
    def color_of(date)
      return Theme::Accent::OVERDUE if @day.later_than?(date)

      @day.on?(date) ? Theme::Accent::TODAY : 0
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
