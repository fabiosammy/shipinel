# frozen_string_literal: true

# The scroll position of the page. It survives reloads: after the file
# changes, the same offset is kept, only clamped to the new page height.

module Shipinel
  # See the file comment.
  class Scroll
    # Pixels moved per mouse wheel notch.
    STEP = 48.0

    attr_reader :offset #: Float

    #: () -> void
    def initialize
      @offset = 0.0
    end

    # Keeps the page between its top and the point where its end reaches
    # the bottom of the window. A page shorter than the window never moves.
    #: (Float wheel, Float page_height, Float window_height) -> void
    def apply(wheel, page_height, window_height)
      wanted = [@offset - (wheel * STEP), page_height - window_height].min
      @offset = wanted.negative? ? 0.0 : wanted
      nil
    end
  end
end
