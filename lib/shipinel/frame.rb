# frozen_string_literal: true

# What one frame shows: the laid-out document (drawn scrolled, only where
# the window shows it), the overlay that stays put (header and
# scrollbar), and how the document sits in the window.

require_relative "draw_list"
require_relative "geometry"
require_relative "header"
require_relative "input"
require_relative "scrollbar"

module Shipinel
  # What a frame looks like on screen: the laid-out page (by identity), where
  # it sits, the checkbox or link under the pointer (raygui draws its hover)
  # and whether the button is down (a release over one is a click). Two
  # frames with the same look draw the same pixels, so the second is
  # skipped.
  class Look
    attr_reader :content #: DrawList
    attr_reader :view #: Viewport
    # The content position of the clickable under the pointer, -1 for none.
    attr_reader :hovered #: Integer

    # @rbs @down: bool

    #: (DrawList content, Viewport view, Integer hovered, bool down) -> void
    def initialize(content, view, hovered, down)
      @content = content
      @view = view
      @hovered = hovered
      @down = down
    end

    # A look no frame has: its page belongs to no frame.
    #: () -> Look
    def self.none
      Look.new(DrawList.new, Viewport.new(0.0, Rect.new(0.0, 0.0, 0.0, 0.0)), -1, false)
    end

    #: () -> bool
    def down?
      @down
    end

    #: (Look other) -> bool
    def same_as?(other)
      @content.equal?(other.content) && @view.same_as?(other.view) && @hovered == other.hovered &&
        @down == other.down?
    end
  end

  # See the file comment.
  class Frame
    attr_reader :content #: DrawList
    attr_reader :overlay #: DrawList
    attr_reader :view #: Viewport

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
      Look.new(@content, @view, clickable_at(input.at), input.down?)
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
