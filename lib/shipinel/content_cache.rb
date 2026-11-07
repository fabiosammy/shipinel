# frozen_string_literal: true

# The last laid-out document, kept until the blocks, the window size or
# the notices change. Laying out measures every word through the fonts,
# which is most of a frame's work; scrolling and pointing reuse the
# layout.

require_relative "draw_list"
require_relative "geometry"
require_relative "markdown/block"

module Shipinel
  # What a layout depends on: the blocks, the window area and the notices.
  # The blocks are compared by identity: DocumentView parses into a new
  # BlockList whenever the file changes. The rest is compared as `text`.
  # The height is part of it although the layout ignores it: a new size has
  # to be drawn.
  class LayoutKey
    attr_reader :blocks #: Markdown::BlockList
    attr_reader :notices #: Array[String]
    attr_reader :text #: String

    #: (Markdown::BlockList blocks, Rect area, Array[String] notices) -> void
    def initialize(blocks, area, notices)
      @blocks = blocks
      @notices = notices
      @text = "#{area.width}x#{area.height} #{notices.join("\n")}"
    end

    # One that no layout matches: its blocks belong to no document.
    #: () -> LayoutKey
    def self.none
      LayoutKey.new(Markdown::BlockList.new, Rect.new(0.0, 0.0, 0.0, 0.0), [])
    end

    #: (LayoutKey other) -> bool
    def same_as?(other)
      @blocks.equal?(other.blocks) && @text == other.text
    end
  end

  # See the file comment.
  class ContentCache
    attr_reader :list #: DrawList

    # @rbs @key: LayoutKey
    # @rbs @changed: bool

    #: () -> void
    def initialize
      @list = DrawList.new
      @key = LayoutKey.none
      @changed = false
    end

    # Whether a new layout was kept since the last call.
    #: () -> bool
    def take_change
      changed = @changed
      @changed = false
      changed
    end

    #: (LayoutKey key) -> bool
    def holds?(key)
      @key.same_as?(key)
    end

    #: (LayoutKey key, DrawList list) -> DrawList
    def keep(key, list)
      @key = key
      @changed = true
      @list = list
    end

    # The fonts changed, so every measured width is stale.
    #: () -> void
    def clear
      @key = LayoutKey.none
      nil
    end
  end
end
