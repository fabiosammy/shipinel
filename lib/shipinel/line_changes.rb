# frozen_string_literal: true

# The lines an edit outside Shipinel changed or removed, found by comparing
# the file's content before and after a poll, and how long they stay
# marked.

module Shipinel
  # The lines of the file that an outside edit changed or added, where it
  # removed lines, and when (Clock.now_ms). Lines are compared by content,
  # so a line that only moved is not marked.
  class LineChanges
    # How long the marks stay, in milliseconds.
    SHOWN_MS = 10_000

    attr_reader :lines #: Array[Integer]
    # The lines that now follow removed ones (the line count when lines
    # were removed at the end).
    attr_reader :removed #: Array[Integer]
    attr_reader :since #: Integer

    #: (Array[Integer] lines, Array[Integer] removed, Integer since) -> void
    def initialize(lines, removed, since)
      @lines = lines
      @removed = removed
      @since = since
    end

    #: () -> LineChanges
    def self.none
      LineChanges.new([], [], 0)
    end

    # The lines of `after` that `before` did not have, and where lines of
    # `before` went missing. A file that appears (nothing before) is new,
    # not changed: nothing is marked.
    #: (String before, String after, Integer now) -> LineChanges
    def self.between(before, after, now)
      return LineChanges.none if before.empty?

      old_lines = before.lines.map(&:chomp)
      new_lines = after.lines.map(&:chomp)
      LineChanges.new(new_lines(old_lines, new_lines), RemovedLines.new(new_lines).after(old_lines), now)
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
      !(@lines.empty? && @removed.empty?) && now - @since >= SHOWN_MS
    end

    # Whether a changed line is within first..last (a block's lines).
    #: (Integer first, Integer last) -> bool
    def within?(first, last)
      LineChanges.any_within?(@lines, first, last)
    end

    # Whether lines were removed just before a line in first..last.
    #: (Integer first, Integer last) -> bool
    def removed_within?(first, last)
      LineChanges.any_within?(@removed, first, last)
    end

    # Written out: Spinel's any?/none? widen (docs/spinel-notes.md).
    #: (Array[Integer] indexes, Integer first, Integer last) -> bool
    def self.any_within?(indexes, first, last)
      position = 0
      while position < indexes.size
        line_index = indexes[position]
        return true if line_index >= first && line_index <= last

        position += 1
      end
      false
    end
  end

  # Where lines went missing: walking the old lines, a run of lines the new
  # file lacks ends at the next old line it still has, and the run is
  # placed before that line's index in the new file. Blank lines are
  # everywhere, so they neither end a run nor place it.
  class RemovedLines
    # @rbs @after: Array[String]
    # @rbs @places: Array[Integer]
    # @rbs @missing: bool

    # One walk per object: `after` is the new file's lines.
    #: (Array[String] after) -> void
    def initialize(after)
      @after = after
      @places = []
      @missing = false
    end

    # The places of the runs of `before` (the old lines) that are gone.
    #: (Array[String] before) -> Array[Integer]
    def after(before)
      before.each { |line| note(line) unless line.strip.empty? }
      @missing ? @places + [@after.size] : @places
    end

    private

    # A kept line ends a run of missing ones, which goes before it.
    #: (String line) -> void
    def note(line)
      kept = @after.include?(line)
      @places << place_of(line) if kept && @missing
      @missing = !kept
      nil
    end

    # The first index of `line` in the new file (Array#index widens).
    #: (String line) -> Integer
    def place_of(line)
      position = 0
      position += 1 while position < @after.size && @after[position] != line
      position
    end
  end
end
