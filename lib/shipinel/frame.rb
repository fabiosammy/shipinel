# frozen_string_literal: true

# What one frame shows: the laid-out document (drawn scrolled, only where
# the window shows it), the overlay that stays put (progress header and
# scrollbar), how the document sits in the window, and the frame rate the
# window should run at now.

require_relative "draw_list"
require_relative "geometry"

module Shipinel
  # See the file comment.
  class Frame
    attr_reader :content #: DrawList
    attr_reader :overlay #: DrawList
    attr_reader :view #: Viewport
    attr_reader :rate #: Integer

    #: (DrawList content, DrawList overlay, Viewport view, Integer rate) -> void
    def initialize(content, overlay, view, rate)
      @content = content
      @overlay = overlay
      @view = view
      @rate = rate
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
