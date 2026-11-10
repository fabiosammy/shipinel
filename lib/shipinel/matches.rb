# frozen_string_literal: true

# Where a find query is on a laid-out page: each match as the pieces of
# text it covers (one, or more when it crosses a style change or a line),
# in page positions, measured with the fonts the page is drawn with.

require_relative "draw_list"
require_relative "font_set"
require_relative "geometry"
require_relative "match_maker"

module Shipinel
  # See the file comment. The query is what the find bar holds; the page
  # is the one it was found on (by identity).
  class Matches
    attr_reader :content #: DrawList
    attr_reader :query #: String

    # @rbs @rects: Array[Rect]
    # @rbs @owners: Array[Integer]

    #: (DrawList content, String query) -> void
    def initialize(content, query)
      @content = content
      @query = query
      @rects = []
      @owners = []
    end

    # No query, on no page.
    #: () -> Matches
    def self.none
      Matches.new(DrawList.new, "")
    end

    # Every place `query` is on `content`, case insensitive. A query of
    # only spaces finds nothing.
    #: (DrawList content, String query, FontSet fonts) -> Matches
    def self.of(content, query, fonts)
      matches = Matches.new(content, query)
      MatchMaker.fill(matches, fonts) unless query.strip.empty?
      matches
    end

    # The matches of `query` on `content`: these, while both are the same.
    #: (String query, DrawList content, FontSet fonts) -> Matches
    def again(query, content, fonts)
      query == @query && @content.equal?(content) ? self : Matches.of(content, query, fonts)
    end

    # A piece of match `number`; an empty one (beside the text) is left out.
    #: (Rect rect, Integer number) -> void
    def add(rect, number)
      return unless rect.width.positive?

      @rects << rect
      @owners << number
      nil
    end

    # How many matches there are.
    #: () -> Integer
    def total
      @owners.empty? ? 0 : @owners[-1] + 1
    end

    #: () -> Integer
    def pieces
      @rects.size
    end

    #: (Integer piece) -> Rect
    def rect_at(piece)
      @rects[piece]
    end

    # The match a piece belongs to.
    #: (Integer piece) -> Integer
    def owner_at(piece)
      @owners[piece]
    end

    # Where match `number` starts: its first piece (an empty rect at the
    # top when there is no match).
    #: (Integer number) -> Rect
    def rect_of(number)
      return Rect.new(0.0, 0.0, 0.0, 0.0) if @rects.empty?

      piece = 0
      piece += 1 while piece + 1 < @owners.size && @owners[piece] < number
      @rects[piece]
    end

    # The first match that starts at or below `top` (a page position), or
    # the first one when none does.
    #: (Float top) -> Integer
    def first_below(top)
      piece = 0
      while piece < @rects.size
        return @owners[piece] if @rects[piece].top >= top

        piece += 1
      end
      0
    end
  end
end
