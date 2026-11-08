# frozen_string_literal: true

# What Shipinel remembers about one plan between runs: where the page was
# scrolled to, the text size and header, the window's size (and position
# where it is known), and the day of the last daily nudge, as the key=value
# lines StateFile keeps.

require_relative "scroll_spot"
require_relative "view"
require_relative "window_place"

module Shipinel
  # Where the page was scrolled to, how it looked, and where the window was.
  class SavedState
    attr_reader :spot #: ScrollSpot
    attr_reader :view #: View
    attr_reader :place #: WindowPlace
    # The date of the last daily nudge, "" for never (Reminder).
    attr_reader :nudged #: String

    #: (ScrollSpot spot, View view, WindowPlace place, String nudged) -> void
    def initialize(spot, view, place, nudged)
      @spot = spot
      @view = view
      @place = place
      @nudged = nudged
    end

    # What a plan never shown before starts with.
    #: (View view, WindowPlace place) -> SavedState
    def self.fresh(view, place)
      SavedState.new(ScrollSpot.none, view, place, "")
    end

    #: () -> String
    def to_text
      "#{spot_lines}#{view_lines}#{@place.to_text}nudged=#{@nudged}\n"
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
