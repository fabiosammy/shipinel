# frozen_string_literal: true

# What the page points out beyond the Markdown itself: dates in open tasks
# that are already past, and the lines an edit outside Shipinel just
# changed (marked beside the text for a few seconds, so the change is
# noticed).

module Shipinel
  # The lines of the file that an outside edit changed or added, and when
  # (Clock.now_ms). Lines are compared by content, so a line that only
  # moved is not marked.
  class LineChanges
    # How long the marks stay, in milliseconds.
    SHOWN_MS = 10_000

    attr_reader :lines #: Array[Integer]
    attr_reader :since #: Integer

    #: (Array[Integer] lines, Integer since) -> void
    def initialize(lines, since)
      @lines = lines
      @since = since
    end

    #: () -> LineChanges
    def self.none
      LineChanges.new([], 0)
    end

    # The lines of `after` that `before` did not have. A file that appears
    # (nothing before) is new, not changed: nothing is marked.
    #: (String before, String after, Integer now) -> LineChanges
    def self.between(before, after, now)
      return LineChanges.none if before.empty?

      LineChanges.new(new_lines(before.lines.map(&:chomp), after.lines.map(&:chomp)), now)
    end

    # The indexes of the lines in `after` that are nowhere in `before`.
    #: (Array[String] before, Array[String] after) -> Array[Integer]
    def self.new_lines(before, after)
      indexes = Array.new(after.size) { |line_index| line_index }
      indexes.reject { |line_index| before.include?(after[line_index].to_s) }
    end

    # The marks have been shown long enough.
    #: (Integer now) -> bool
    def expired?(now)
      !@lines.empty? && now - @since >= SHOWN_MS
    end

    # Whether a changed line is within first..last (a block's lines).
    # Written out: Spinel's any?/none? widen (docs/spinel-notes.md).
    #: (Integer first, Integer last) -> bool
    def within?(first, last)
      position = 0
      while position < @lines.size
        line_index = @lines[position]
        return true if line_index >= first && line_index <= last

        position += 1
      end
      false
    end
  end

  # See the file comment: today's date ("2026-11-08", "" to point out no
  # dates) and the lines just changed outside.
  class Highlights
    # Example match: "2026-11-05" in "(due 2026-11-05)"
    DATE = /(?<date>\d{4}-\d{2}-\d{2})/

    attr_reader :today #: String
    attr_reader :changes #: LineChanges

    #: (String today, LineChanges changes) -> void
    def initialize(today, changes)
      @today = today
      @changes = changes
    end

    #: () -> Highlights
    def self.none
      Highlights.new("", LineChanges.none)
    end

    # A word holding a date before today. ISO dates compare in time order
    # as text.
    #: (String word) -> bool
    def overdue?(word)
      match = DATE.match(word)
      return false unless match

      !@today.empty? && match[:date].to_s < @today
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
      @today == other.today && @changes.lines == other.changes.lines
    end
  end

  # Keeps the Highlights up to date on every file poll: marks the lines an
  # outside edit changed and lets the marks go after a while; and moves the
  # date on at midnight. Shipinel's own checkbox flips are saved and read
  # back between two polls, so they are never marked.
  class Highlighter
    attr_reader :highlights #: Highlights

    #: (String today) -> void
    def initialize(today)
      @highlights = Highlights.new(today, LineChanges.none)
    end

    # `before` and `after`: the file's content around this poll's reload.
    #: (String before, String after, Integer now) -> void
    def poll(before, after, now)
      changes = before == after ? @highlights.changes : LineChanges.between(before, after, now)
      @highlights = Highlights.new(@highlights.today, changes.expired?(now) ? LineChanges.none : changes)
      nil
    end

    #: (String today) -> void
    def turn_to(today)
      @highlights = Highlights.new(today, @highlights.changes)
      nil
    end
  end
end
