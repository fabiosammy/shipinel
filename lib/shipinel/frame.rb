# frozen_string_literal: true

# What one frame shows: the laid-out document (drawn scrolled, only where
# the window shows it), the overlay that stays put (progress header and
# scrollbar), how the document sits in the window, and how the frame runs
# (Pace: its rate, and whether it is drawn at all).

require_relative "activity"
require_relative "draw_list"
require_relative "geometry"

module Shipinel
  # See the file comment.
  class Frame
    attr_reader :content #: DrawList
    attr_reader :overlay #: DrawList
    attr_reader :view #: Viewport
    attr_reader :pace #: Pace

    #: (DrawList content, DrawList overlay, Viewport view, Pace pace) -> void
    def initialize(content, overlay, view, pace)
      @content = content
      @overlay = overlay
      @view = view
      @pace = pace
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

    #: () -> Integer
    def overlay_size
      @overlay.size
    end

    #: (Integer position) -> DrawCommand
    def overlay_at(position)
      @overlay.at(position)
    end
  end
end
