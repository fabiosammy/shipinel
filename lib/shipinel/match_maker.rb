# frozen_string_literal: true

# Turns the places a find query starts in a page's text into the pieces of
# its Matches: the part of each piece of text a match covers, measured with
# the fonts the page is drawn with.

require_relative "draw_list"
require_relative "font_set"
require_relative "geometry"
require_relative "page_text"
require_relative "span"

module Shipinel
  # Turns the places a query starts in the page text into the pieces of
  # Matches, one match after the other.
  class MatchMaker
    # @rbs @page: PageText
    # @rbs @fonts: FontSet
    # @rbs @matches: Matches
    # The piece of text the last match started in: matches only go forward.
    # @rbs @piece: Integer

    #: (PageText page, FontSet fonts, Matches matches) -> void
    def initialize(page, fonts, matches)
      @page = page
      @fonts = fonts
      @matches = matches
      @piece = 0
    end

    # Every match of `matches`' query on its page, measured with `fonts`.
    #: (Matches matches, FontSet fonts) -> void
    def self.fill(matches, fonts)
      MatchMaker.new(PageText.of(matches.content), fonts, matches).add_all(PageText.fold(matches.query))
    end

    # Where the characters of `span` are drawn in `run`, as measured with
    # `fonts`; offsets outside its text are cut to it, and nothing of it is
    # an empty rect.
    #: (TextRun run, Span span, FontSet fonts) -> Rect
    def self.part(run, span, fonts)
      cut = span.within(run.text.size)
      box = run.rect
      Rect.new(box.left + MatchMaker.width_of(run, Span.new(0, cut.from), fonts), box.top,
               MatchMaker.width_of(run, cut, fonts), box.height)
    end

    # How wide the characters of `span` are in `run`.
    #: (TextRun run, Span span, FontSet fonts) -> Float
    def self.width_of(run, span, fonts)
      fonts.text_width(run.text[span.from, span.length] || "", run.style)
    end

    # Every place `query` (folded) starts in the page text, without
    # overlapping.
    #: (String query) -> void
    def add_all(query)
      text = @page.codepoints
      wanted = query.codepoints
      at = PageText.next_in(text, 0, wanted)
      at = PageText.next_in(text, add(at, wanted.size), wanted) while at >= 0
      nil
    end

    # The match that starts at `from` in the page text, `length`
    # characters long; returns where the next one may start.
    #: (Integer from, Integer length) -> Integer
    def add(from, length)
      span = Span.new(from, from + length)
      advance_to(from)
      cover_from(@piece, span, @matches.total)
      span.to
    end

    private

    # On to the last piece that starts at or before `from`.
    #: (Integer from) -> void
    def advance_to(from)
      last = @page.pieces - 1
      @piece += 1 while @piece < last && @page.start_at(@piece + 1) <= from
      nil
    end

    # Every piece from `piece` on that starts before `span` ends.
    #: (Integer piece, Span span, Integer number) -> void
    def cover_from(piece, span, number)
      while piece < @page.pieces && @page.start_at(piece) < span.to
        cover(piece, span, number)
        piece += 1
      end
      nil
    end

    # The part of piece `piece` that `span` covers, as part of match
    # `number`.
    #: (Integer piece, Span span, Integer number) -> void
    def cover(piece, span, number)
      @matches.add(MatchMaker.part(@page.run_at(piece), span.from_start(@page.start_at(piece)), @fonts), number)
    end
  end
end
