# frozen_string_literal: true

# What a frame marks on the page: the selection and the find bar's matches
# (backgrounds under the text, Painter), the keyboard focus (a ring around
# its checkbox) and the outline (a panel of sections under the header).

require_relative "focus"
require_relative "outline"
require_relative "search"
require_relative "selection"

module Shipinel
  # See the file comment.
  class Marks
    attr_reader :selection #: Selection
    attr_reader :search #: Search
    attr_reader :focus #: Focus
    attr_reader :outline #: Outline

    #: (Selection selection, Search search, Focus focus, Outline outline) -> void
    def initialize(selection, search, focus, outline)
      @selection = selection
      @search = search
      @focus = focus
      @outline = outline
    end

    # Nothing selected, the find bar and the outline closed, no focus.
    #: () -> Marks
    def self.none
      Marks.new(Selection.none, Search.none, Focus.none, Outline.none)
    end

    # The same marks with another selection.
    #: (Selection selection) -> Marks
    def with_selection(selection)
      Marks.new(selection, @search, @focus, @outline)
    end

    #: (Search search) -> Marks
    def with_search(search)
      Marks.new(@selection, search, @focus, @outline)
    end

    #: (Focus focus) -> Marks
    def with_focus(focus)
      Marks.new(@selection, @search, focus, @outline)
    end

    #: (Outline outline) -> Marks
    def with_outline(outline)
      Marks.new(@selection, @search, @focus, outline)
    end

    #: (Marks other) -> bool
    def same_as?(other)
      @selection.same_as?(other.selection) && @search.same_as?(other.search) && @focus.same_as?(other.focus) &&
        @outline.same_as?(other.outline)
    end
  end
end
