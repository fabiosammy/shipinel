# frozen_string_literal: true

# What one frame shows: the laid-out document (drawn scrolled, only where
# the window shows it), the overlay that stays put (header and
# scrollbar), how the document sits in the window, and the text selected.

require_relative "draw_list"
require_relative "geometry"
require_relative "header"
require_relative "input"
require_relative "scrollbar"
require_relative "look"
require_relative "selection"

module Shipinel
  # See the file comment.
  class Frame
    attr_reader :content #: DrawList
    attr_reader :overlay #: DrawList
    attr_reader :view #: Viewport
    # The text selected on this page (Selection.none until `select`).
    attr_reader :selection #: Selection

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
      @selection = Selection.none
    end

    # The frame shows `selection` (worked out from this frame, Selection#after).
    # (Not `select`, an Enumerable name: docs/spinel-notes.md.)
    #: (Selection selection) -> Frame
    def showing(selection)
      @selection = selection
      self
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
      Look.new(@content, @view, PointerOn.new(clickable_at(input.at), input.down?), @selection)
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
