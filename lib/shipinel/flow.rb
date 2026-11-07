# frozen_string_literal: true

# The page being laid out, top to bottom: where the next line goes, and the
# draw commands so far. LineWrap breaks one block's text into lines.

require_relative "draw_list"
require_relative "geometry"
require_relative "line_wrap"
require_relative "markdown/inline"
require_relative "theme"

module Shipinel
  # See the file comment. Layout decides what goes on the page; Flow decides
  # where.
  class Flow
    BULLET = "•"
    # Tabs in code become this, since the fonts have no tab glyph.
    TAB = "    "

    attr_reader :top #: Float
    attr_reader :right #: Float

    # @rbs @layout: Layout
    # @rbs @list: DrawList

    #: (Layout layout, Float width) -> void
    def initialize(layout, width)
      @layout = layout
      @list = DrawList.new
      @top = Theme::Spacing::MARGIN
      @right = width - Theme::Spacing::MARGIN
    end

    #: () -> Styles
    def styles
      @layout.styles
    end

    # Measures text and splits it between the text and symbol fonts.
    #: () -> FontSet
    def fonts
      @layout.fonts
    end

    #: () -> bool
    def at_top?
      @top <= Theme::Spacing::MARGIN
    end

    #: (Float pixels) -> void
    def gap(pixels)
      @top += pixels
      nil
    end

    #: (DrawCommand command) -> void
    def add(command)
      @list.add(command)
    end

    # Wrapped to the page width, starting `indent` pixels in.
    #: (String text, Float indent, TextStyle style) -> void
    def text(text, indent, style)
      wrap = LineWrap.new(self, Theme::Spacing::MARGIN + indent, style)
      spans = Markdown::Inline.parse(text)
      spans.size.times { |position| wrap.write(spans.at(position)) }
      gap(style.line_height)
    end

    # Centered on the line that the item's text starts on.
    #: (Float indent, TaskClick click) -> void
    def checkbox(indent, click)
      size = styles.checkbox_size
      top = @top + ((styles.body.line_height - size) / 2)
      add(Checkbox.new(Rect.new(Theme::Spacing::MARGIN + indent, top, size, size), click))
    end

    #: (Float indent, TextStyle style) -> void
    def bullet(indent, style)
      left = Theme::Spacing::MARGIN + indent + (style.size * 0.4)
      add(TextRun.new(BULLET, Rect.new(left, @top, fonts.text_width(BULLET, style), style.line_height), style))
    end

    # Not wrapped: code keeps its lines.
    #: (String text) -> void
    def code_line(text)
      style = styles.code_block
      line = full_width(style.line_height)
      add(Box.new(line, Theme::Surface::CODE_BACKGROUND))
      add(TextRun.new(text.gsub("\t", TAB), line.indented(style.size), style))
      gap(line.height)
    end

    # A one-pixel line with half a block gap above and below.
    #: () -> void
    def rule
      half = styles.size * Theme::Spacing::BLOCK_GAP / 2
      @top += half
      add(Box.new(full_width(1.0), Theme::Surface::RULE))
      gap(half)
    end

    #: () -> DrawList
    def finish
      @list.finish(@top + Theme::Spacing::MARGIN)
    end

    private

    #: (Float height) -> Rect
    def full_width(height)
      Rect.new(Theme::Spacing::MARGIN, @top, @right - Theme::Spacing::MARGIN, height)
    end
  end
end
