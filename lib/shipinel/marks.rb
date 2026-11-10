# frozen_string_literal: true

# What a frame marks on the page's text: the selection and the find bar's
# matches. Both are drawn as backgrounds under the text (Painter).

require_relative "search"
require_relative "selection"

module Shipinel
  # See the file comment.
  class Marks
    attr_reader :selection #: Selection
    attr_reader :search #: Search

    #: (Selection selection, Search search) -> void
    def initialize(selection, search)
      @selection = selection
      @search = search
    end

    # Nothing selected, the find bar closed.
    #: () -> Marks
    def self.none
      Marks.new(Selection.none, Search.none)
    end

    #: (Marks other) -> bool
    def same_as?(other)
      @selection.same_as?(other.selection) && @search.same_as?(other.search)
    end
  end
end
