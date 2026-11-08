# frozen_string_literal: true

# Keeps what the page points out (Highlights) up to date with every file
# poll and with the date, and says where a new day opens.

require_relative "highlights"
require_relative "markdown/block"
require_relative "poller"
require_relative "saved_state"
require_relative "scroll_spot"

module Shipinel
  # Keeps the Highlights up to date on every file poll: marks the lines an
  # outside edit changed and lets the marks go after a while; and moves the
  # date on at midnight, when the page goes to the new day's heading. Shipinel's own checkbox flips are saved and read
  # back between two polls, so they are never marked.
  class Highlighter
    attr_reader :highlights #: Highlights

    #: (Day day) -> void
    def initialize(day)
      @highlights = Highlights.new(day, LineChanges.none)
    end

    # `before` and `after`: the file's content around this poll's reload.
    #: (String before, String after, Integer now) -> void
    def poll(before, after, now)
      changes = before == after ? @highlights.changes : LineChanges.between(before, after, now)
      @highlights = Highlights.new(@highlights.day, changes.expired?(now) ? LineChanges.none : changes)
      nil
    end

    # After a file poll: marks and the date updated; where the page goes,
    # which is today's heading when midnight just passed (ScrollSpot.none
    # otherwise: it stays).
    #: (String before, String after, Markdown::BlockList blocks) -> ScrollSpot
    def reloaded(before, after, blocks)
      poll(before, after, Clock.now_ms)
      turned_to?(Day.today) ? today_in(blocks) : ScrollSpot.none
    end

    # Where a plan opens: today's heading when it was last saved on another
    # day and has one, else where it was left.
    #: (SavedState saved, Markdown::BlockList blocks) -> ScrollSpot
    def opening(saved, blocks)
      today = today_in(blocks)
      saved.days.seen_on?(@highlights.today) || !today.aimed? ? saved.spot : today
    end

    #: (Markdown::BlockList blocks) -> ScrollSpot
    def today_in(blocks)
      ScrollSpot.today(blocks, @highlights.day)
    end

    # Moves to `day`; whether that is a new day (midnight passed).
    #: (Day day) -> bool
    def turned_to?(day)
      new_day = day.date != @highlights.today
      @highlights = Highlights.new(day, @highlights.changes)
      new_day
    end
  end
end
