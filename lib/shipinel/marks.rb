# frozen_string_literal: true

# What a frame marks on the page: the selection and the find bar's matches
# (backgrounds under the text, Painter), and the keyboard focus (a ring
# around its checkbox).

require_relative "focus"
require_relative "search"
require_relative "selection"

module Shipinel
  # See the file comment.
  class Marks
    attr_reader :selection #: Selection
    attr_reader :search #: Search
    attr_reader :focus #: Focus

    #: (Selection selection, Search search, Focus focus) -> void
    def initialize(selection, search, focus)
      @selection = selection
      @search = search
      @focus = focus
    end

    # Nothing selected, the find bar closed, no focus.
    #: () -> Marks
    def self.none
      Marks.new(Selection.none, Search.none, Focus.none)
    end

    # The same marks with another selection.
    #: (Selection selection) -> Marks
    def with_selection(selection)
      Marks.new(selection, @search, @focus)
    end

    #: (Search search) -> Marks
    def with_search(search)
      Marks.new(@selection, search, @focus)
    end

    #: (Focus focus) -> Marks
    def with_focus(focus)
      Marks.new(@selection, @search, focus)
    end

    #: (Marks other) -> bool
    def same_as?(other)
      @selection.same_as?(other.selection) && @search.same_as?(other.search) && @focus.same_as?(other.focus)
    end
  end
end
