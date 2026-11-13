# frozen_string_literal: true

# What one frame shows: the laid-out document (drawn scrolled, only where
# the window shows it), the overlay that stays put (header and
# scrollbar), how the document sits in the window, and what is marked on
# its text: the selection and the find bar's matches.

require_relative "draw_list"
require_relative "geometry"
require_relative "header"
require_relative "input"
require_relative "scrollbar"
require_relative "look"
require_relative "marks"
require_relative "outline_panel"
require_relative "page_in_view"

module Shipinel
  # See the file comment.
  class Frame
    attr_reader :content #: DrawList
    attr_reader :overlay #: DrawList
    attr_reader :view #: Viewport
    # The selection and the matches (Marks.none until `showing`).
    attr_reader :marks #: Marks

    # The frame for a page whose scrollbar is where this frame's input left
    # it: the header and the bar make the overlay.
    #: (DrawList content, Header header, Scrollbar bar) -> Frame
    def self.of(content, header, bar)
      overlay = DrawList.new
      header.add_to(overlay)
      bar.add_to(overlay)
      Frame.new(content, overlay, bar.viewport)
    end

    #: (DrawList content, DrawList overlay, Viewport view) -> void
    def initialize(content, overlay, view)
      @content = content
      @overlay = overlay
      @view = view
      @marks = Marks.none
    end

    # The frame shows `marks` (worked out from this frame: Selection#after,
    # Search#after). (Not `select`, an Enumerable name: docs/spinel-notes.md.)
    #: (Marks marks) -> Frame
    def showing(marks)
      @marks = marks
      marks.focus.ring_into(@overlay, PageInView.new(@content, @view))
      self
    end

    # The frame with `panel` (the outline's) in its overlay.
    #: (OutlinePanel panel) -> Frame
    def adding(panel)
      panel.add_to(@overlay)
      self
    end

    # The checkbox Space ticks this frame (the keyboard's click), if any.
    #: () -> DrawCommand?
    def pressed
      @marks.focus.pressed_in(@content)
    end

    # The text selected on this page.
    #: () -> Selection
    def selection
      @marks.selection
    end

    # Where `at`, a window position, is on the page.
    #: (Point at) -> Point
    def page_point(at)
      at.down(@view.shift)
    end

    # Whether `at` is over the page's text, where a press starts a
    # selection: below the header, off the scrollbar, not on a checkbox or
    # a link.
    #: (Point at) -> bool
    def on_text?(at)
      at.top >= @view.top && clickable_at(at).negative? && !@overlay.covers?(at)
    end

    # Whether a click on the checkbox or link drawn at `area` (a window
    # position) reaches it: below the header, not under the overlay (the
    # outline's panel, the find bar).
    #: (Rect area) -> bool
    def reachable?(area)
      area.top >= @view.top && !@overlay.covers?(area.corner)
    end

    # The lists are read by index, as DrawList is (docs/spinel-notes.md).
    #: () -> Integer
    def content_size
      @content.size
    end

    #: (Integer position) -> DrawCommand
    def content_at(position)
      @content.at(position)
    end

    # How this frame looks with the pointer and button of `input`.
    #: (Input input) -> Look
    def look(input)
      Look.new(@content, @view, PointerOn.new(clickable_at(input.at), input.down?), @marks)
    end

    # The content position of the checkbox or link under `at` where the
    # window shows it (below the header, as Painter clicks), or -1.
    #: (Point at) -> Integer
    def clickable_at(at)
      position = 0
      while position < @content.size
        return position if clickable_under?(@content.at(position), at)

        position += 1
      end
      -1
    end

    #: () -> Integer
    def overlay_size
      @overlay.size
    end

    #: (Integer position) -> DrawCommand
    def overlay_at(position)
      @overlay.at(position)
    end

    private

    #: (DrawCommand command, Point at) -> bool
    def clickable_under?(command, at)
      return false unless command.is_a?(Clickable)

      area = command.rect.up(@view.shift)
      area.top >= @view.top && area.contains?(at)
    end
  end
end
