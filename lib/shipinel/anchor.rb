# frozen_string_literal: true

# Where each heading starts on the laid-out page: its plain title, the slug
# that names it in the state file, and its top. The section the window is
# in is the last heading at or above the top of the window.

module Shipinel
  # One heading on the page.
  class Anchor
    # Example match: " — " in "Goal 1 — Drata": a run that is not a letter
    # or digit.
    NOT_WORD = /[^[:alnum:]]+/
    # Example match: the "-" at either end of "-goal-1-".
    EDGE_DASHES = /\A-+|-+\z/

    attr_reader :title #: String
    attr_reader :slug #: String
    attr_reader :top #: Float

    #: (String title, Float top) -> void
    def initialize(title, top)
      @title = title
      @slug = Anchor.slug_of(title)
      @top = top
    end

    #: (String other_slug) -> bool
    def named?(other_slug)
      @slug == other_slug
    end

    # "Goal 1 — Drata monitoring tests" -> "goal-1-drata-monitoring-tests".
    #: (String title) -> String
    def self.slug_of(title)
      title.downcase.gsub(NOT_WORD, "-").gsub(EDGE_DASHES, "")
    end
  end

  # The anchors of one page, top to bottom. Read by index: kept in this
  # ivar the array stays typed under Spinel (docs/spinel-notes.md).
  class AnchorList
    NONE = -1

    # @rbs @anchors: Array[Anchor]

    #: () -> void
    def initialize
      @anchors = []
    end

    #: (Anchor anchor) -> void
    def add(anchor)
      @anchors << anchor
      nil
    end

    #: (Integer position) -> Anchor
    def at(position)
      @anchors[position]
    end

    # The position of the last heading at or above page offset `offset`.
    #: (Float offset) -> Integer
    def above(offset)
      last = NONE
      position = 0
      while position < @anchors.size && @anchors[position].top <= offset
        last = position
        position += 1
      end
      last
    end

    # The position of the first heading with this slug, or NONE.
    #: (String slug) -> Integer
    def named(slug)
      position = 0
      while position < @anchors.size
        return position if @anchors[position].named?(slug)

        position += 1
      end
      NONE
    end

    # The title of the section at `offset`, or `fallback` above the first
    # heading.
    #: (Float offset, String fallback) -> String
    def title_above(offset, fallback)
      position = above(offset)
      position == NONE ? fallback : @anchors[position].title
    end
  end
end
