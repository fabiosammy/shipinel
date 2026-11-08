# frozen_string_literal: true

# The lines an edit outside Shipinel changed, found by comparing the file's
# content before and after a poll, and how long they stay marked.

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
end
