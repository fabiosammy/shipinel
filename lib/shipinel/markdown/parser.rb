# frozen_string_literal: true

# Turns Markdown source into a BlockList. Works line by line and keeps each
# block's line index. Lines inside a fenced code block are only ever
# CodeLines, so a "- [ ]" inside a fence is never a task.

require_relative "block"
require_relative "line_reader"
require_relative "list_nesting"
require_relative "source_line"

module Shipinel
  module Markdown
    # See the file comment. One Parser reads one document.
    class Parser
      # @rbs @blocks: BlockList
      # @rbs @nesting: ListNesting
      # @rbs @fence: String?
      # @rbs @paragraph: Paragraph?

      #: (String source) -> BlockList
      def self.parse(source)
        new.read(source)
      end

      #: () -> void
      def initialize
        @blocks = BlockList.new
        @nesting = ListNesting.new
        @fence = nil
        @paragraph = nil
      end

      # `lines` keeps "\r\n" endings, which `chomp` removes.
      #: (String source) -> BlockList
      def read(source)
        line_index = 0
        source.lines.each do |text|
          read_line(SourceLine.new(text.chomp, line_index))
          line_index += 1
        end
        @blocks
      end

      private

      #: (SourceLine line) -> void
      def read_line(line)
        open_marker = @fence
        if open_marker then read_fenced(line, open_marker)
        elsif line.blank? then @paragraph = nil
        else read_text(line)
        end
        nil
      end

      #: (SourceLine line, String open_marker) -> void
      def read_fenced(line, open_marker)
        if LineReader.closes_fence?(line, open_marker)
          @fence = nil
        else
          @blocks.add(CodeLine.new(line.line_index, line.text))
        end
        nil
      end

      #: (SourceLine line) -> void
      def read_text(line)
        marker = LineReader.fence_marker(line)
        marker.empty? ? read_block(line) : open_fence(marker)
      end

      #: (String marker) -> void
      def open_fence(marker)
        @paragraph = nil
        @nesting.reset
        @fence = marker
        nil
      end

      #: (SourceLine line) -> void
      def read_block(line)
        block = LineReader.heading(line) || LineReader.rule(line) ||
                LineReader.task(line, @nesting) || LineReader.bullet(line, @nesting)
        block ? add_block(block) : add_paragraph_line(line)
        nil
      end

      #: (Block block) -> void
      def add_block(block)
        @paragraph = nil
        @nesting.reset unless block.is_a?(ListItem)
        @blocks.add(block)
      end

      #: (SourceLine line) -> void
      def add_paragraph_line(line)
        paragraph = @paragraph
        return paragraph.append(line.text.strip) if paragraph

        start_paragraph(line)
      end

      # Text that is not a list item ends the list.
      #: (SourceLine line) -> void
      def start_paragraph(line)
        @nesting.reset
        paragraph = Paragraph.new(line.line_index, line.text.strip)
        @paragraph = paragraph
        @blocks.add(paragraph)
      end
    end
  end
end
