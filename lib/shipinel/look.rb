# frozen_string_literal: true

# What a frame looks like on screen, so that a frame looking like the last
# one drawn is not drawn again (Typesetter#fresh).

require_relative "draw_list"
require_relative "geometry"
require_relative "marks"

module Shipinel
  # What a frame looks like on screen: the laid-out page (by identity), where
  # it sits, the checkbox or link under the pointer (raygui draws its hover)
  # and whether the button is down (a release over one is a click), and the
  # selection and matches marked on it. Two
  # frames with the same look draw the same pixels, so the second is
  # skipped.
  class Look
    attr_reader :content #: DrawList
    attr_reader :view #: Viewport
    attr_reader :pointer #: PointerOn
    attr_reader :marks #: Marks

    #: (DrawList content, Viewport view, PointerOn pointer, Marks marks) -> void
    def initialize(content, view, pointer, marks)
      @content = content
      @view = view
      @pointer = pointer
      @marks = marks
    end

    # A look no frame has: its page belongs to no frame.
    #: () -> Look
    def self.none
      Look.new(DrawList.new, Viewport.new(0.0, Rect.new(0.0, 0.0, 0.0, 0.0)), PointerOn.new(-1, false), Marks.none)
    end

    #: (Look other) -> bool
    def same_as?(other)
      @content.equal?(other.content) && @view.same_as?(other.view) && @pointer.same_as?(other.pointer) &&
        @marks.same_as?(other.marks)
    end
  end

  # What the pointer does to a frame's look: the checkbox or link under it
  # (raygui draws its hover; -1 for none) and whether the button is down (a
  # release over one is a click).
  class PointerOn
    attr_reader :hovered #: Integer

    # @rbs @down: bool

    #: (Integer hovered, bool down) -> void
    def initialize(hovered, down)
      @hovered = hovered
      @down = down
    end

    #: () -> bool
    def down?
      @down
    end

    #: (PointerOn other) -> bool
    def same_as?(other)
      @hovered == other.hovered && @down == other.down?
    end
  end
end
