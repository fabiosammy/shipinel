# frozen_string_literal: true

# Text selected with the mouse, for Ctrl+C: dragging over the page selects
# the words between where the button went down and where the pointer is, in
# reading order (line by line, left to right). Points are page positions,
# so the selection stays put while the page scrolls. A new layout (the
# file changed, the window resized, a zoom) drops it, since its words moved.

require_relative "draw_list"
require_relative "geometry"
require_relative "input"
require_relative "reading_order"
require_relative "selected_lines"

module Shipinel
  # One selection on one laid-out page, or none. A new value replaces it
  # whenever it changes (Selection#after), so a frame can compare it.
  class Selection
    # Past any page: the end of a select-all.
    FAR = 1.0e9

    attr_reader :content #: DrawList
    attr_reader :from #: Point
    attr_reader :to #: Point
    # :none, :dragging (the button is down), :released (on the frame the
    # button came up after a drag, when that release clicks nothing) or
    # :done.
    attr_reader :state #: Symbol

    #: (DrawList content, Point from, Point to, Symbol state) -> void
    def initialize(content, from, to, state)
      @content = content
      @from = from
      @to = to
      @state = state
    end

    #: () -> Selection
    def self.none
      origin = Point.new(0.0, 0.0)
      Selection.new(DrawList.new, origin, origin, :none)
    end

    # Ctrl+A: every word of the page.
    #: (DrawList content) -> Selection
    def self.all(content)
      Selection.new(content, Point.new(0.0, 0.0), Point.new(FAR, FAR), :done)
    end

    # Where a drag that starts at `at` (a page position) begins.
    #: (DrawList content, Point at) -> Selection
    def self.starting(content, at)
      Selection.new(content, at, at, :dragging)
    end

    # (Not `any?`: Enumerable names pull in Spinel's widening builtins,
    # docs/spinel-notes.md.)
    #: () -> bool
    def active?
      @state != :none
    end

    # A release that ends a drag is not a click on what it lands on.
    #: () -> bool
    def released?
      @state == :released
    end

    # Same page, same state, same ends.
    #: (Selection other) -> bool
    def same_as?(other)
      @state == other.state && @content.equal?(other.content) && same_ends?(other)
    end

    #: (Selection other) -> bool
    def same_ends?(other)
      @from.same_as?(other.from) && @to.same_as?(other.to)
    end

    # The selection after this frame's input, on the page `frame` shows.
    #: (Input input, Frame frame) -> Selection
    def after(input, frame)
      content = frame.content
      return Selection.all(content) if input.keys.select_all?
      return Selection.none if stale?(content)

      input.pressed? ? Selection.pressed(input, frame) : moved(input, frame)
    end

    # A selection on another layout (the file changed, a resize, a zoom).
    #: (DrawList content) -> bool
    def stale?(content)
      active? && !@content.equal?(content)
    end

    # No press this frame: while the button is down a drag follows the
    # pointer; anything else settles.
    #: (Input input, Frame frame) -> Selection
    def moved(input, frame)
      return settled unless @state == :dragging

      input.down? ? to_point(frame.page_point(input.at)) : released
    end

    # A press on plain text starts a drag; one anywhere else (a checkbox, a
    # link, the header, the scrollbar) clears the selection.
    #: (Input input, Frame frame) -> Selection
    def self.pressed(input, frame)
      at = input.at
      frame.on_text?(at) ? Selection.starting(frame.content, frame.page_point(at)) : Selection.none
    end

    # The drag goes on to `at`, a page position.
    #: (Point at) -> Selection
    def to_point(at)
      Selection.new(@content, @from, at, :dragging)
    end

    # The button came up: a drag that went nowhere was a click, which
    # selects nothing.
    #: () -> Selection
    def released
      @from.same_as?(@to) ? Selection.none : Selection.new(@content, @from, @to, :released)
    end

    # The frame after a release.
    #: () -> Selection
    def settled
      @state == :released ? Selection.new(@content, @from, @to, :done) : self
    end

    # Whether the piece of text in `rect` (a page position) is selected: it
    # comes after the start and before the end in reading order. A point
    # beside a line counts from the middle of each piece.
    #: (Rect rect) -> bool
    def covers?(rect)
      return false unless active?

      ReadingOrder.side(first_point, rect).negative? && ReadingOrder.side(last_point, rect).positive?
    end

    # Whether `command` is page text that `selection` covers.
    #: (Selection selection, DrawCommand command) -> bool
    def self.highlights?(selection, command)
      command.is_a?(TextRun) && selection.covers?(command.rect)
    end

    # The selected text, a line for each line on the page.
    #: () -> String
    def text
      lines = SelectedLines.new
      @content.size.times { |position| SelectedLines.take(lines, @content.at(position), self) }
      lines.text
    end

    private

    # The end that comes first in reading order (a drag may go up).
    #: () -> Point
    def first_point
      ReadingOrder.before?(@to, @from) ? @to : @from
    end

    #: () -> Point
    def last_point
      ReadingOrder.before?(@to, @from) ? @from : @to
    end
  end
end
