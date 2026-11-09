# frozen_string_literal: true

# The last laid-out document, kept until the blocks, the window size or
# the notices change. Laying out measures every word through the fonts,
# which is most of a frame's work; scrolling and pointing reuse the
# layout.

require_relative "draw_list"
require_relative "frame"
require_relative "geometry"
require_relative "highlights"
require_relative "markdown/block"

module Shipinel
  # What a layout depends on, cheap to build and compare every frame: the
  # blocks (by identity: DocumentView parses into a new BlockList whenever
  # the file changes), the problem from the last click (shown as a notice),
  # what the page points out (today's date, lines changed outside), and the
  # window size. The height is part of it although the layout
  # ignores it: a new size has to be drawn. Font notices change only when
  # the fonts are loaded, which clears the cache.
  class LayoutKey
    attr_reader :blocks #: Markdown::BlockList
    attr_reader :problem #: String
    attr_reader :highlights #: Highlights
    attr_reader :area #: Rect

    #: (Markdown::BlockList blocks, String problem, Highlights highlights, Rect area) -> void
    def initialize(blocks, problem, highlights, area)
      @blocks = blocks
      @problem = problem
      @highlights = highlights
      @area = area
    end

    # One that no layout matches: its blocks belong to no document.
    #: () -> LayoutKey
    def self.none
      LayoutKey.new(Markdown::BlockList.new, "", Highlights.none, Rect.new(0.0, 0.0, 0.0, 0.0))
    end

    #: (LayoutKey other) -> bool
    def same_as?(other)
      @blocks.equal?(other.blocks) && @problem == other.problem && @highlights.same_as?(other.highlights) &&
        same_size?(other.area)
    end

    private

    #: (Rect other) -> bool
    def same_size?(other)
      @area.width == other.width && @area.height == other.height
    end
  end

  # See the file comment.
  class ContentCache
    attr_reader :list #: DrawList

    # @rbs @key: LayoutKey
    # @rbs @shown: Look

    #: () -> void
    def initialize
      @list = DrawList.new
      @key = LayoutKey.none
      @shown = Look.none
    end

    # Whether the last frame drawn looked like this.
    #: (Look look) -> bool
    def shown?(look)
      @shown.same_as?(look)
    end

    #: (Look look) -> void
    def show(look)
      @shown = look
      nil
    end

    #: (LayoutKey key) -> bool
    def holds?(key)
      @key.same_as?(key)
    end

    #: (LayoutKey key, DrawList list) -> DrawList
    def keep(key, list)
      @key = key
      @list = list
    end

    # The fonts changed, so every measured width is stale.
    #: () -> void
    def clear
      @key = LayoutKey.none
      @shown = Look.none
      nil
    end
  end
end
