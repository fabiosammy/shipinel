# frozen_string_literal: true

# Turns blocks into positioned draw commands for a page of a given width:
# headings, wrapped paragraphs, indented bullets and tasks with their
# checkboxes, code lines on a background, rules. Pure: text is measured,
# and split into text and symbol pieces, by the injected FontSet (or a fake
# in tests).

require_relative "draw_list"
require_relative "flow"
require_relative "list_layout"
require_relative "quote_layout"
require_relative "markdown/block"
require_relative "font_set"
require_relative "highlights"
require_relative "styles"
require_relative "table_layout"

module Shipinel
  # See the file comment. One Layout lays out one page, for one width.
  #
  # Blocks are dispatched with `case` and their fields passed on, never the
  # block itself: Spinel does not pass a value narrowed by `is_a?` into a
  # parameter typed with the subclass (docs/spinel-notes.md).
  class Layout
    attr_reader :styles #: Styles
    attr_reader :fonts #: FontSet

    # @rbs @flow: Flow
    # @rbs @in_code: bool

    #: (FontSet fonts, Styles styles, Float width) -> void
    def initialize(fonts, styles, width)
      @fonts = fonts
      @styles = styles
      @flow = Flow.new(self, width)
      @in_code = false
    end

    # The same layout, pointing out `highlights` (none by default).
    #: (Highlights highlights) -> Layout
    def marking(highlights)
      @flow.page.point_out(highlights)
      self
    end

    # Notices (a missing file, a failed save, a font problem) go first.
    #: (Markdown::BlockList blocks, Array[String] notices) -> DrawList
    def arrange(blocks, notices)
      notices.each { |notice| place_text(notice, @styles.problem) }
      blocks.size.times { |position| place(blocks.at(position), blocks.last_line_of(position)) }
      @flow.finish
    end

    private

    # The page marks the block as Highlights asks, and counts it under its
    # headings (DrawList#begin_block, #end_block).
    #: (Markdown::Block block, Integer last) -> void
    def place(block, last)
      room_around_code(block)
      page = @flow.page
      page.begin_block(block, last)
      place_kind(block)
      page.end_block(block)
    end

    # A run of code lines gets a little room above and below it.
    #: (Markdown::Block block) -> void
    def room_around_code(block)
      code = block.is_a?(Markdown::CodeLine)
      @flow.gap(block_gap / 2) if code != @in_code && !@flow.at_top?
      @in_code = code
    end

    # Headings and list items carry more than their text. Each branch reads
    # its kind's fields here, since Spinel cannot pass the narrowed block on
    # (.reek.yml).
    #: (Markdown::Block block) -> void
    def place_kind(block)
      text = block.text
      case block
      when Markdown::Heading then place_heading(text, block.level)
      when Markdown::Task then list(block.depth).task(text, block.line_index, block.checked?)
      when Markdown::Bullet then list(block.depth).bullet(text, block.marker)
      else place_plain(block, text)
      end
    end

    #: (Markdown::Block block, String text) -> void
    def place_plain(block, text)
      case block
      when Markdown::Paragraph then place_text(text, @styles.body)
      when Markdown::CodeLine then @flow.code_line(text)
      when Markdown::Table then place_table(text, block.columns, block.header_rows)
      when Markdown::Quote then place_quote(text)
      else @flow.rule
      end
    end

    #: (String text, Integer level) -> void
    def place_heading(text, level)
      @flow.gap(block_gap) unless @flow.at_top?
      @flow.page.anchors.mark(text, @flow.top, level)
      @flow.text(text, 0.0, @styles.heading(level))
      @flow.gap(block_gap / 2)
    end

    # A notice or a paragraph: wrapped text and a gap.
    #: (String text, TextStyle style) -> void
    def place_text(text, style)
      @flow.text(text, 0.0, style)
      @flow.gap(block_gap)
    end

    #: (String text) -> void
    def place_quote(text)
      QuoteLayout.new(@flow).place(text)
      @flow.gap(block_gap)
    end

    #: (String cells, Integer columns, Integer header_rows) -> void
    def place_table(cells, columns, header_rows)
      TableLayout.new(@flow, cells, columns, header_rows).place
      @flow.gap(block_gap)
    end

    #: (Integer depth) -> ListLayout
    def list(depth)
      ListLayout.new(@flow, depth)
    end

    #: () -> Float
    def block_gap
      @styles.size * Theme::Spacing::BLOCK_GAP
    end
  end
end
