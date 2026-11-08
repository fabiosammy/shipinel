# frozen_string_literal: true

# Where each heading starts on the laid-out page: its plain title, the slug
# that names it in the state file, its top, and the tasks under it (up to
# the next heading of the same or a higher level, so a section counts its
# subsections). The section the window is in is the last heading at or
# above the top of the window.

require_relative "markdown/inline"
require_relative "markdown/task_progress"

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
    # The tasks under this heading, counted while the page is laid out.
    attr_reader :progress #: Markdown::TaskProgress

    #: (String title, Float top) -> void
    def initialize(title, top)
      @title = title
      @slug = Anchor.slug_of(title)
      @top = top
      @progress = Markdown::TaskProgress.new
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

  # What the header's section line shows: the section's title and, when it
  # has tasks, how many of them are done ("3 of 8"; "" otherwise). (Not
  # `count`: that name pulls in Spinel's widening Enumerable builtins,
  # docs/spinel-notes.md.)
  class SectionLine
    attr_reader :title #: String
    attr_reader :tasks #: String

    #: (String title, String tasks) -> void
    def initialize(title, tasks)
      @title = title
      @tasks = tasks
    end
  end

  # The anchors of one page, top to bottom, and the headings still open
  # while it is laid out (with their levels), which count the tasks met.
  # Read by index: kept in ivars the arrays stay typed under Spinel
  # (docs/spinel-notes.md).
  class AnchorList
    NONE = -1

    # @rbs @anchors: Array[Anchor]
    # @rbs @open: Array[Anchor]
    # @rbs @levels: Array[Integer]

    #: () -> void
    def initialize
      @anchors = []
      @open = []
      @levels = []
    end

    # A heading of `level` closes the open ones of the same or a deeper
    # level (a higher number) and opens its own.
    #: (Anchor anchor, Integer level) -> void
    def add(anchor, level)
      close_from(level)
      @anchors << anchor
      @open << anchor
      @levels << level
      nil
    end

    # A heading of `level` with this (markdown) text starts at `top`; its
    # anchor's title is the plain text.
    #: (String text, Float top, Integer level) -> void
    def mark(text, top, level)
      add(Anchor.new(Markdown::Inline.parse(text).plain, top), level)
    end

    # Counts a block (if it is a task) under every open heading.
    #: (Markdown::Block block) -> void
    def add_block(block)
      @open.each { |anchor| anchor.progress.add(block) }
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

    # The section at `offset`, or `fallback` (with no count) above the
    # first heading.
    #: (Float offset, String fallback) -> SectionLine
    def section_at(offset, fallback)
      position = above(offset)
      return SectionLine.new(fallback, "") if position == NONE

      anchor = @anchors[position]
      SectionLine.new(anchor.title, anchor.progress.count_text)
    end

    private

    #: (Integer level) -> void
    def close_from(level)
      while !@levels.empty? && @levels[-1] >= level
        @levels.pop
        @open.pop
      end
      nil
    end
  end
end
