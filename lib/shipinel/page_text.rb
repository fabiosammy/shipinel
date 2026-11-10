# frozen_string_literal: true

# The text of a laid-out page as one string to search, in lower case, with
# each piece of text (a TextRun) and where it starts in it. Pieces on
# different lines are joined by a space, so a phrase wrapped over two lines
# is found.

require_relative "draw_list"

module Shipinel
  # See the file comment.
  class PageText
    attr_reader :text #: String

    # @rbs @starts: Array[Integer]
    # @rbs @runs: Array[TextRun]
    # @rbs @top: Float

    #: () -> void
    def initialize
      @text = +""
      @starts = []
      @runs = []
      @top = -1.0
    end

    # The text of every TextRun of `content`, in drawing order.
    #: (DrawList content) -> PageText
    def self.of(content)
      page = PageText.new
      content.size.times { |position| PageText.take(page, content.at(position)) }
      page
    end

    # Adds `command` when it is text. (A copy: Spinel cannot keep a value
    # narrowed by is_a? in a TextRun array, docs/spinel-notes.md.)
    #: (PageText page, DrawCommand command) -> void
    def self.take(page, command)
      page.add(TextRun.new(command.text, command.rect, command.style)) if command.is_a?(TextRun)
      nil
    end

    # Lower case where that keeps the length, so that an offset into the
    # page text is one into the piece's own text.
    #: (String text) -> String
    def self.fold(text)
      folded = text.downcase
      folded.size == text.size ? folded : text
    end

    # Where `query` next starts in `text` at or after `from`, or -1; both
    # as codepoints, compared as integers (slicing a UTF-8 String at every
    # offset was too slow on a long plan; String#index widens under Spinel).
    #: (Array[Integer] text, Integer from, Array[Integer] query) -> Integer
    def self.next_in(text, from, query)
      last = text.size - query.size
      from += 1 while from <= last && !PageText.starts_at?(text, from, query)
      from > last || query.empty? ? -1 : from
    end

    # Whether `text` holds `query` from `at` on.
    #: (Array[Integer] text, Integer at, Array[Integer] query) -> bool
    def self.starts_at?(text, at, query)
      length = query.size
      matched = 0
      matched += 1 while matched < length && text[at + matched] == query[matched]
      matched == length
    end

    # The next piece of text.
    #: (TextRun run) -> void
    def add(run)
      separate(run.rect.top)
      @starts << @text.size
      @runs << run
      @text << PageText.fold(run.text)
      nil
    end

    # How many pieces of text the page has.
    #: () -> Integer
    def pieces
      @starts.size
    end

    # Where piece `piece` starts in the page text.
    #: (Integer piece) -> Integer
    def start_at(piece)
      @starts[piece]
    end

    #: (Integer piece) -> TextRun
    def run_at(piece)
      @runs[piece]
    end

    # The text as codepoints, for searching.
    #: () -> Array[Integer]
    def codepoints
      @text.codepoints
    end

    private

    # A piece drawn at `top`, below the last one, starts a new line: a
    # space separates them.
    #: (Float top) -> void
    def separate(top)
      @text << " " if top != @top && !@text.empty? && !@text.end_with?(" ")
      @top = top
      nil
    end
  end
end
