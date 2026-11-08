# frozen_string_literal: true

# What Shipinel remembers about one plan between runs: where the page was
# scrolled to, the text size and header, the window's size (and position
# where it is known), the day of the last daily nudge, and the day it was
# saved (a new day opens at today's heading), as the key=value lines
# StateFile keeps.

require_relative "scroll_spot"
require_relative "view"
require_relative "window_place"

module Shipinel
  # The days a plan's state remembers: the last daily nudge (Reminder) and
  # the last save (a new day opens at today's heading); "" for never.
  class StateDays
    attr_reader :nudged #: String
    attr_reader :seen #: String

    #: (String nudged, String seen) -> void
    def initialize(nudged, seen)
      @nudged = nudged
      @seen = seen
    end

    # Whether it was last saved on `date`.
    #: (String date) -> bool
    def seen_on?(date)
      @seen == date
    end

    #: () -> String
    def to_text
      "nudged=#{@nudged}\nday=#{@seen}\n"
    end
  end

  # Where the page was scrolled to, how it looked, and where the window was.
  class SavedState
    attr_reader :spot #: ScrollSpot
    attr_reader :view #: View
    attr_reader :place #: WindowPlace
    # The last daily nudge and the last save.
    attr_reader :days #: StateDays

    #: (ScrollSpot spot, View view, WindowPlace place, StateDays days) -> void
    def initialize(spot, view, place, days)
      @spot = spot
      @view = view
      @place = place
      @days = days
    end

    # What a plan never shown before starts with.
    #: (View view, WindowPlace place) -> SavedState
    def self.fresh(view, place)
      SavedState.new(ScrollSpot.none, view, place, StateDays.new("", ""))
    end

    #: () -> String
    def to_text
      "#{spot_lines}#{view_lines}#{@place.to_text}#{@days.to_text}"
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
