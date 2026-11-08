# frozen_string_literal: true

# A place on the page that survives edits and restarts: the section (by its
# heading's slug) and how far into it, with the plain offset for a page
# without that heading. Also the place a new day opens at: today's heading.

require_relative "anchor"
require_relative "day"
require_relative "markdown/block"

module Shipinel
  # See the file comment.
  class ScrollSpot
    attr_reader :slug #: String
    attr_reader :within #: Float
    attr_reader :offset #: Float

    #: (String slug, Float within, Float offset) -> void
    def initialize(slug, within, offset)
      @slug = slug
      @within = within
      @offset = offset
    end

    # Nowhere to go: a page offset is never negative.
    #: () -> ScrollSpot
    def self.none
      ScrollSpot.new("", 0.0, -1.0)
    end

    # Where a page scrolled to `offset` is.
    #: (Float offset, AnchorList anchors) -> ScrollSpot
    def self.at(offset, anchors)
      position = anchors.above(offset)
      return ScrollSpot.new("", 0.0, offset) if position == AnchorList::NONE

      anchor = anchors.at(position)
      ScrollSpot.new(anchor.slug, offset - anchor.top, offset)
    end

    # The top of the first heading about `day` (Day#heading?), or
    # ScrollSpot.none when the plan has none.
    #: (Markdown::BlockList blocks, Day day) -> ScrollSpot
    def self.today(blocks, day)
      position = 0
      while position < blocks.size
        title = ScrollSpot.title_of(blocks.at(position))
        return ScrollSpot.new(Anchor.slug_of(title), 0.0, 0.0) if day.heading?(title)

        position += 1
      end
      ScrollSpot.none
    end

    # A heading's plain title; "" for any other block.
    #: (Markdown::Block block) -> String
    def self.title_of(block)
      block.is_a?(Markdown::Heading) ? Markdown::Inline.parse(block.text).plain : ""
    end

    #: () -> bool
    def aimed?
      @offset >= 0.0
    end

    # The offset of this spot on a page laid out with these anchors.
    #: (AnchorList anchors) -> Float
    def offset_in(anchors)
      position = anchors.named(@slug)
      position == AnchorList::NONE ? @offset : anchors.at(position).top + @within
    end

    # The same spot on the page drawn `ratio` times bigger.
    #: (Float ratio) -> ScrollSpot
    def scaled(ratio)
      ScrollSpot.new(@slug, @within * ratio, @offset * ratio)
    end
  end
end
