# frozen_string_literal: true

# What Shipinel remembers about one plan between runs: where the page was
# scrolled to, the text size and header, and the window's size (and
# position where it is known), as the key=value lines StateFile keeps.

require_relative "scroll_spot"
require_relative "view"
require_relative "window_place"

module Shipinel
  # Where the page was scrolled to, how it looked, and where the window was.
  class SavedState
    attr_reader :spot #: ScrollSpot
    attr_reader :view #: View
    attr_reader :place #: WindowPlace

    #: (ScrollSpot spot, View view, WindowPlace place) -> void
    def initialize(spot, view, place)
      @spot = spot
      @view = view
      @place = place
    end

    #: () -> String
    def to_text
      "#{spot_lines}#{view_lines}#{@place.to_text}"
    end

    private

    #: () -> String
    def spot_lines
      "section=#{@spot.slug}\nwithin=#{@spot.within}\noffset=#{@spot.offset}\n"
    end

    #: () -> String
    def view_lines
      "size=#{@view.size}\nheader=#{@view.header? ? 1 : 0}\n"
    end
  end
end
