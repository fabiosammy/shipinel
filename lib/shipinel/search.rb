# frozen_string_literal: true

# The find bar: closed, or open with what was typed into it and the match
# it is on. Ctrl+F opens it empty, typing and Backspace change the query
# (the matches are found again, case insensitive), Enter goes to the next
# match and Shift+Enter to the previous one (round the ends), Escape
# closes it. It never hides anything: matches are only highlighted.

require_relative "draw_list"
require_relative "font_set"
require_relative "geometry"
require_relative "keyboard"
require_relative "matches"
require_relative "scroll_spot"
require_relative "theme"

module Shipinel
  # See the file comment. A new value replaces it whenever it changes.
  class Search
    attr_reader :matches #: Matches

    # @rbs @open: bool
    # @rbs @current: Integer

    #: (bool open, Matches matches, Integer current) -> void
    def initialize(open, matches, current)
      @open = open
      @matches = matches
      @current = current
    end

    # The find bar closed.
    #: () -> Search
    def self.none
      Search.new(false, Matches.none, 0)
    end

    # The query after Backspace (one character fewer) and then what was
    # typed.
    #: (String query, FindKeys keys) -> String
    def self.edited(query, keys)
      kept = keys.erase? ? query[0, [query.size - 1, 0].max] || "" : query
      "#{kept}#{keys.typed}"
    end

    #: () -> bool
    def open?
      @open
    end

    #: () -> String
    def query
      @matches.query
    end

    #: () -> Integer
    def total
      @matches.total
    end

    # The match the bar is on, from 0 (0 when there is none).
    #: () -> Integer
    def current
      size = total
      size.zero? ? 0 : ((@current % size) + size) % size
    end

    # The bar after this frame's keys, on `content`, whose text is
    # measured with `fonts`. New matches start from the first one at or
    # below `top`, the top of the window on the page.
    #: (FindKeys keys, DrawList content, FontSet fonts) -> Search
    def after(keys, content, fonts)
      return Search.new(true, Matches.none, 0) if keys.open?
      return Search.none if keys.close?
      return self unless @open

      typed_into(keys, content, fonts)
    end

    # Whether the matches were found again since `before` (the query or
    # the page changed).
    #: (Search before) -> bool
    def found_anew?(before)
      !@matches.equal?(before.matches)
    end

    # Matches found anew start from the first one at or below the top of
    # `view`; otherwise the bar stays on its match.
    #: (Search before, Viewport view) -> Search
    def placed(before, view)
      found_anew?(before) ? Search.new(@open, @matches, @matches.first_below(view.offset)) : self
    end

    # Where the window goes to show the current match when `view` does not
    # show all of it: the match a third of the way down. ScrollSpot.none
    # when it is in view, or there is none.
    #: (Viewport view) -> ScrollSpot
    def aim(view)
      match = @matches.rect_of(current)
      hidden = total.positive? && !view.holds?(match)
      hidden ? ScrollSpot.new("", 0.0, [match.top - (view.height / 3), 0.0].max) : ScrollSpot.none
    end

    # The background of a piece: brighter for the match the bar is on.
    #: (Integer piece) -> Integer
    def color_of(piece)
      @matches.owner_at(piece) == current ? Theme::Found::CURRENT : Theme::Found::MATCH
    end

    # Same bar, same matches, on the same one.
    #: (Search other) -> bool
    def same_as?(other)
      @open == other.open? && @matches.equal?(other.matches) && current == other.current
    end

    private

    # The open bar after typing, Backspace or Enter: the matches are found
    # again when the query or the page changed, and start over.
    #: (FindKeys keys, DrawList content, FontSet fonts) -> Search
    def typed_into(keys, content, fonts)
      matches = @matches.again(Search.edited(query, keys), content, fonts)
      Search.new(true, matches, matches.equal?(@matches) ? @current + keys.step : 0)
    end
  end
end
