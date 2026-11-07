# frozen_string_literal: true

# The last laid-out document, kept until the blocks, the window width or
# the notices change. Laying out measures every word through the fonts,
# which is most of a frame's work; scrolling and pointing reuse the
# layout.

require_relative "draw_list"
require_relative "markdown/block"

module Shipinel
  # What a layout depends on. The blocks are compared by identity:
  # DocumentView parses into a new BlockList whenever the file changes.
  # The rest (width, notices) is in `text`.
  class LayoutKey
    attr_reader :blocks #: Markdown::BlockList
    attr_reader :text #: String

    #: (Markdown::BlockList blocks, String text) -> void
    def initialize(blocks, text)
      @blocks = blocks
      @text = text
    end

    # One that no layout matches: its blocks belong to no document.
    #: () -> LayoutKey
    def self.none
      LayoutKey.new(Markdown::BlockList.new, "")
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

    #: () -> void
    def initialize
      @list = DrawList.new
      @key = LayoutKey.none
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
      nil
    end
  end
end
