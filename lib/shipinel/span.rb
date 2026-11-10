# frozen_string_literal: true

# A stretch of a text, by character offsets: from `from` up to `to`
# (excluded). Find matches are spans of the page text.

module Shipinel
  # See the file comment.
  class Span
    attr_reader :from #: Integer
    attr_reader :to #: Integer

    #: (Integer from, Integer to) -> void
    def initialize(from, to)
      @from = from
      @to = to
    end

    #: () -> Integer
    def length
      @to - @from
    end

    # The same stretch counted from `start` instead of 0.
    #: (Integer start) -> Span
    def from_start(start)
      Span.new(@from - start, @to - start)
    end

    # The part inside a text of `size` characters (not with `clamp`, which
    # Spinel widens: docs/spinel-notes.md); empty when none is.
    #: (Integer size) -> Span
    def within(size)
      first = @from.negative? ? 0 : [@from, size].min
      Span.new(first, @to < first ? first : [@to, size].min)
    end
  end
end
