# frozen_string_literal: true

# Draw commands: what Layout decides and Painter draws, positioned on the
# page (not yet scrolled). A checkbox keeps its task's line index, so a
# click maps back to that source line.

require_relative "anchor"
require_relative "geometry"
require_relative "highlights"
require_relative "markdown/block"
require_relative "task_toggler"
require_relative "theme"

module Shipinel
  # The base of every draw command: the area of the page it covers. Like
  # Markdown::Block, subclasses only add data, so a DrawList compiles to one
  # typed array under Spinel.
  class DrawCommand
    attr_reader :rect #: Rect

    #: (Rect rect) -> void
    def initialize(rect)
      @rect = rect
    end
  end

  # Text in one style; drawn from the top-left corner of its rect.
  class TextRun < DrawCommand
    attr_reader :text #: String
    attr_reader :style #: TextStyle

    #: (String text, Rect rect, TextStyle style) -> void
    def initialize(text, rect, style)
      super(rect)
      @text = text
      @style = style
    end
  end

  # A filled rectangle.
  class Box < DrawCommand
    attr_reader :color #: Integer

    #: (Rect rect, Integer color) -> void
    def initialize(rect, color)
      super(rect)
      @color = color
    end
  end

  # Something the user can click: the pointer turns into a hand over it.
  class Clickable < DrawCommand
  end

  # A task checkbox, with the click a user would make on it: its task's
  # line index and the state the file had when it was laid out.
  class Checkbox < Clickable
    attr_reader :click #: TaskClick

    #: (Rect rect, TaskClick click) -> void
    def initialize(rect, click)
      super(rect)
      @click = click
    end
  end

  # Where a link's text was drawn: a click inside opens the url.
  class LinkArea < Clickable
    attr_reader :url #: String

    #: (Rect rect, String url) -> void
    def initialize(rect, url)
      super(rect)
      @url = url
    end
  end

  # The marks Highlights asks for while one page is laid out: today's
  # heading in the accent color, past dates in open tasks, and a mark in
  # the left margin beside every text line of a block changed outside.
  class ChangeMarks
    # @rbs @highlights: Highlights
    # What the block being placed gets: :changed (a bar beside every text
    # line), :removed (a notch over its first line: lines were removed
    # just before it) or :none.
    # @rbs @mark: Symbol
    # @rbs @open_task: bool
    # @rbs @marked_top: Float

    #: (Highlights highlights) -> void
    def initialize(highlights)
      @highlights = highlights
      @mark = :none
      @open_task = false
      @marked_top = -1.0
    end

    # A heading's style: in the accent color when it is about today.
    #: (String text, TextStyle style) -> TextStyle
    def heading_style(text, style)
      return style unless @highlights.day.heading?(Markdown::Inline.parse(text).plain)

      style.with_color(Theme::Accent::TODAY)
    end

    # A word cut around the past date it holds, in an open task only.
    #: (String word) -> DatedWord
    def overdue_parts(word)
      @open_task ? @highlights.overdue_parts(word) : DatedWord.plain(word)
    end

    # The block that starts here and ends on line `last` is placed next.
    #: (Markdown::Block block, Integer last) -> void
    def start_block(block, last)
      @mark = mark_of(block.line_index, last)
      @open_task = Markdown::Task.open?(block)
      nil
    end

    #: () -> void
    def end_block
      @mark = :none
      @open_task = false
      nil
    end

    # The mark for a command just added to the page, if it starts a text
    # line of a marked block (the pieces of a line share its top).
    #: (DrawCommand command) -> DrawCommand?
    def mark_for(command)
      return nil unless starts_marked_line?(command)

      line = command.rect
      @marked_top = line.top
      @mark == :changed ? ChangeMarks.bar(line) : notch(line)
    end

    # Text of a marked block, on a line that has no mark yet.
    #: (DrawCommand command) -> bool
    def starts_marked_line?(command)
      @mark != :none && command.is_a?(TextRun) && command.rect.top != @marked_top
    end

    # The bar beside a changed text line.
    #: (Rect line) -> Box
    def self.bar(line)
      Box.new(Rect.new(Theme::ChangeMark::LEFT, line.top, Theme::ChangeMark::WIDTH, line.height),
              Theme::Accent::CHANGED)
    end

    private

    #: (Integer first, Integer last) -> Symbol
    def mark_of(first, last)
      return :changed if @highlights.changed?(first, last)

      @highlights.removed_before?(first, last) ? :removed : :none
    end

    # The notch over the first text line of a block that removed lines came
    # just before; the block's other lines get none.
    #: (Rect line) -> Box
    def notch(line)
      @mark = :none
      Box.new(Rect.new(Theme::ChangeMark::LEFT, line.top, Theme::ChangeMark::NOTCH_WIDTH, Theme::ChangeMark::WIDTH),
              Theme::Accent::CHANGED)
    end
  end

  # The commands of one laid-out page, in drawing order, its height, where
  # its headings start, and the marks Highlights asks for.
  class DrawList
    attr_reader :height #: Float
    attr_reader :anchors #: AnchorList
    attr_reader :marks #: ChangeMarks

    # @rbs @commands: Array[DrawCommand]

    #: () -> void
    def initialize
      @commands = []
      @height = 0.0
      @anchors = AnchorList.new
      @marks = ChangeMarks.new(Highlights.none)
    end

    # Points out `highlights` on this page (nothing by default).
    #: (Highlights highlights) -> void
    def point_out(highlights)
      @marks = ChangeMarks.new(highlights)
      nil
    end

    # A heading of `level` with this (markdown) text starts at `top`.
    #: (String text, Float top, Integer level) -> void
    def heading(text, top, level)
      @anchors.mark(text, top, level)
    end

    # A heading's style, in the accent color when it is about today.
    #: (String text, TextStyle style) -> TextStyle
    def heading_style(text, style)
      @marks.heading_style(text, style)
    end

    # The block that ends on source line `last` is placed next: what it
    # shows is marked as Highlights asks.
    #: (Markdown::Block block, Integer last) -> void
    def begin_block(block, last)
      @marks.start_block(block, last)
    end

    # The block was placed: it is counted under the open headings (only
    # tasks count), and the marks stop.
    #: (Markdown::Block block) -> void
    def end_block(block)
      @anchors.add_block(block)
      @marks.end_block
    end

    # A text line of a block changed outside also gets its mark.
    #: (DrawCommand command) -> void
    def add(command)
      @commands << command
      mark = @marks.mark_for(command)
      @commands << mark if mark
      nil
    end

    #: () -> Integer
    def size
      @commands.size
    end

    #: (Integer position) -> DrawCommand
    def at(position)
      @commands[position]
    end

    # Whether any command covers `point` (the header and scrollbar of an
    # overlay, over the page). (Not any?: Spinel widens it.)
    #: (Point point) -> bool
    def covers?(point)
      @commands.map { |command| command.rect.contains?(point) }.include?(true)
    end

    # The heading the page is scrolled into at `offset`, with its count,
    # or `fallback` above the first heading.
    #: (Float offset, String fallback) -> SectionLine
    def section_at(offset, fallback)
      @anchors.section_at(offset, fallback)
    end

    #: (Float height) -> DrawList
    def finish(height)
      @height = height
      self
    end
  end
end
