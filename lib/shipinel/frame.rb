# frozen_string_literal: true

# What one frame shows: the laid-out document (drawn scrolled, only where
# the window shows it), the overlay that stays put (progress header and
# scrollbar), and how the document sits in the window.

require_relative "draw_list"
require_relative "geometry"
require_relative "progress_header"
require_relative "scrollbar"

module Shipinel
  # See the file comment.
  class Frame
    attr_reader :content #: DrawList
    attr_reader :overlay #: DrawList
    attr_reader :view #: Viewport

    # The frame for a page whose scrollbar is where this frame's input left
    # it: the header and the bar make the overlay.
    #: (DrawList content, ProgressHeader header, Scrollbar bar) -> Frame
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
