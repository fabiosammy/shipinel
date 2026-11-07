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
      # The paragraph or table the next line may continue.
      # @rbs @open: Block?

      #: (String source) -> BlockList
      def self.parse(source)
        new.read(source)
      end

      #: () -> void
      def initialize
        @blocks = BlockList.new
        @nesting = ListNesting.new
        @fence = nil
        @open = nil
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
        elsif line.blank? then @open = nil
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
        marker.empty? ? read_content(line) : open_fence(marker)
      end

      # A quote, a table row, or a line LineReader recognises.
      #: (SourceLine line) -> void
      def read_content(line)
        text = line.text
        quoted = Quote.text_in(text)
        quoted ? add_quote_line(line, quoted) : read_table_or_block(line, text)
      end

      #: (SourceLine line, String text) -> void
      def read_table_or_block(line, text)
        cells = Table.cells_in(text)
        cells.empty? ? read_block(line) : add_table_row(line, cells)
      end

      #: (String marker) -> void
      def open_fence(marker)
        @open = nil
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
        @open = nil
        @nesting.reset unless block.is_a?(ListItem)
        @blocks.add(block)
      end

      # (Not `return open.add_row(...)`: Spinel types the result of a call
      # on a value narrowed by is_a? as untyped.)
      #: (SourceLine line, Array[String] cells) -> void
      def add_table_row(line, cells)
        open = @open
        if open.is_a?(Table)
          open.add_row(cells)
        else
          start(Table.new(line.line_index, cells))
        end
        nil
      end

      # (Not `return open.append(...)`: see add_table_row.)
      #: (SourceLine line, String text) -> void
      def add_quote_line(line, text)
        open = @open
        if text.empty? then @open = nil
        elsif open.is_a?(Quote) then open.append(text)
        else start(Quote.new(line.line_index, text))
        end
        nil
      end

      #: (SourceLine line) -> void
      def add_paragraph_line(line)
        open = @open
        text = line.text.strip
        return open.append(text) if open.is_a?(Paragraph)

        start(Paragraph.new(line.line_index, text))
      end

      # A paragraph or table that later lines may continue. It ends any list.
      #: (Block block) -> void
      def start(block)
        @nesting.reset
        @open = block
        @blocks.add(block)
      end
    end
  end
end
