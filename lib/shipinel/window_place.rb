# frozen_string_literal: true

# Where the window is and how big: its size always, its position only where
# the window system lets a program know and set it (X11; on Wayland the
# compositor alone places windows, by window rules).

require_relative "geometry"

module Shipinel
  # See the file comment.
  class WindowPlace
    # Left and top are the position on screen, width and height the size.
    attr_reader :rect #: Rect

    # @rbs @placed: bool

    #: (Rect rect, bool placed) -> void
    def initialize(rect, placed)
      @rect = rect
      @placed = placed
    end

    # A window of this size, placed by the window system.
    #: (Integer width, Integer height) -> WindowPlace
    def self.sized(width, height)
      WindowPlace.new(Rect.new(0.0, 0.0, width.to_f, height.to_f), false)
    end

    # Whether the position is known and can be set.
    #: () -> bool
    def placed?
      @placed
    end

    # The lines SavedState keeps: the size, and the position where known.
    #: () -> String
    def to_text
      size = "width=#{@rect.width.round}\nheight=#{@rect.height.round}\n"
      @placed ? "#{size}x=#{@rect.left.round}\ny=#{@rect.top.round}\n" : size
    end

    # The inside of the window, where the page is drawn.
    #: () -> Rect
    def area
      Rect.new(0.0, 0.0, @rect.width, @rect.height)
    end
  end
end
