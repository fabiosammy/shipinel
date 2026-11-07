# frozen_string_literal: true

# Turns blocks into positioned draw commands for a page of a given width:
# headings, wrapped paragraphs, indented bullets and tasks with their
# checkboxes, code lines on a background, rules. Pure: text is measured
# through the injected TextMeasure (or a fake in tests).

require_relative "draw_list"
require_relative "flow"
require_relative "markdown/block"
require_relative "text_measure"
require_relative "styles"
require_relative "task_toggler"

module Shipinel
  # See the file comment. One Layout lays out one page, for one width.
  #
  # Blocks are dispatched with `case` and their fields passed on, never the
  # block itself: Spinel does not pass a value narrowed by `is_a?` into a
  # parameter typed with the subclass (docs/spinel-notes.md).
  class Layout
    attr_reader :styles #: Styles

    # @rbs @measurer: TextMeasure
    # @rbs @flow: Flow
    # @rbs @in_code: bool

    #: (TextMeasure measurer, Styles styles, Float width) -> void
    def initialize(measurer, styles, width)
      @measurer = measurer
      @styles = styles
      @flow = Flow.new(self, width)
      @in_code = false
    end

    #: (Markdown::BlockList blocks) -> DrawList
    def arrange(blocks)
      position = 0
      while position < blocks.size
        place(blocks.at(position))
        position += 1
      end
      @flow.finish
    end

    #: (String text, TextStyle style) -> Float
    def width_of(text, style)
      @measurer.text_width(text, style)
    end

    private

    # A run of code lines gets a little room above and below it.
    #: (Markdown::Block block) -> void
    def place(block)
      code = block.is_a?(Markdown::CodeLine)
      @flow.gap(block_gap / 2) if code != @in_code && !@flow.at_top?
      @in_code = code
      place_kind(block)
    end

    # Headings and list items carry more than their text.
    #: (Markdown::Block block) -> void
    def place_kind(block)
      text = block.text
      case block
      when Markdown::Heading then place_heading(text, block.level)
      when Markdown::ListItem then place_item(block.depth, text, TaskClick.for_block(block))
      else place_plain(block)
      end
    end

    #: (Markdown::Block block) -> void
    def place_plain(block)
      text = block.text
      case block
      when Markdown::Paragraph then place_paragraph(text)
      when Markdown::CodeLine then @flow.code_line(text)
      else @flow.rule
      end
    end

    #: (String text, Integer level) -> void
    def place_heading(text, level)
      @flow.gap(block_gap) unless @flow.at_top?
      @flow.text(text, 0.0, @styles.heading(level))
      @flow.gap(block_gap / 2)
    end

    #: (String text) -> void
    def place_paragraph(text)
      @flow.text(text, 0.0, @styles.body)
      @flow.gap(block_gap)
    end

    #: (Integer depth, String text, TaskClick? click) -> void
    def place_item(depth, text, click)
      indent = indent_for(depth)
      @flow.text(text, text_indent(indent), mark(indent, click))
    end

    # Draws the checkbox or bullet, and returns the style of the item's text.
    #: (Float indent, TaskClick? click) -> TextStyle
    def mark(indent, click)
      return bullet(indent) unless click

      @flow.checkbox(indent, click)
      click.checked? ? @styles.done : @styles.body
    end

    #: (Float indent) -> TextStyle
    def bullet(indent)
      style = @styles.body
      @flow.bullet(indent, style)
      style
    end

    #: (Integer depth) -> Float
    def indent_for(depth)
      depth * @styles.size * Theme::Spacing::INDENT
    end

    # Where an item's text starts: after its bullet or checkbox.
    #: (Float indent) -> Float
    def text_indent(indent)
      indent + (@styles.size * Theme::Spacing::MARKER)
    end

    #: () -> Float
    def block_gap
      @styles.size * Theme::Spacing::BLOCK_GAP
    end
  end
end
