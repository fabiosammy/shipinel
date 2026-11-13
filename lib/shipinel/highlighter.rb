# frozen_string_literal: true

# Keeps what the page points out (Highlights) up to date with every file
# poll and with the date, and says where a new day opens; also the text
# selected with the mouse and the find bar.

require_relative "clipboard"
require_relative "highlights"
require_relative "markdown/block"
require_relative "poller"
require_relative "find_bar"
require_relative "focus"
require_relative "font_set"
require_relative "marks"
require_relative "saved_state"
require_relative "scroll_spot"
require_relative "search"
require_relative "selection"
require_relative "view"

module Shipinel
  # Keeps the Highlights up to date on every file poll: marks the lines an
  # outside edit changed and lets the marks go after a while; and moves the
  # date on at midnight, when the page goes to the new day's heading. Shipinel's own checkbox flips are saved and read
  # back between two polls, so they are never marked.
  class Highlighter
    attr_reader :highlights #: Highlights
    # The selection, the find bar and the keyboard focus (Marks).
    attr_reader :marks #: Marks

    # @rbs @fonts: FontSet

    # `fonts` measure the matches, as the page is drawn.
    #: (Day day, FontSet fonts) -> void
    def initialize(day, fonts)
      @highlights = Highlights.new(day, LineChanges.none)
      @marks = Marks.none
      @fonts = fonts
    end

    # The find bar (Search).
    #: () -> Search
    def search
      @marks.search
    end

    # The find bar's and the focus's keys, on `content` shown in `view`:
    # where the window goes to show the match or checkbox they moved to
    # (the match when both did; ScrollSpot.none when neither did).
    #: (KeyPress keys, DrawList content, Viewport view) -> ScrollSpot
    def moved(keys, content, view)
      found = searching(keys.for_finding, content, view)
      focused = focusing(keys.for_focus, PageInView.new(content, view))
      found.aimed? ? found : focused
    end

    # The find bar after `finding`: where the window goes to show the
    # match it is on, when it moved to another one.
    #: (FindKeys finding, DrawList content, Viewport view) -> ScrollSpot
    def searching(finding, content, view)
      before = search
      found = before.after(finding, content, @fonts).placed(before, view)
      @marks = @marks.with_search(found)
      found.found_anew?(before) || !finding.step.zero? ? found.aim(view) : ScrollSpot.none
    end

    # The keyboard focus after `steps`: where the window goes to show the
    # checkbox Tab moved to.
    #: (FocusKeys steps, PageInView page) -> ScrollSpot
    def focusing(steps, page)
      focus = @marks.focus.after(steps, page)
      @marks = @marks.with_focus(focus)
      steps.step.zero? ? ScrollSpot.none : focus.aim(page)
    end

    # The find bar as it is, in `view`'s status text, at the bottom of
    # `window`.
    #: (View view, Rect window) -> FindBar
    def find_bar(view, window)
      FindBar.new(search, view.styles.status, window, @fonts)
    end

    # `frame`, showing the selection as this frame's input leaves it and
    # the matches, with `bar` in its overlay; Ctrl+C puts the selected text
    # on the clipboard.
    #: (Input input, Frame frame, FindBar bar) -> Frame
    def selecting(input, frame, bar)
      selection = @marks.selection.after(input, frame)
      @marks = @marks.with_selection(selection)
      Clipboard.copy(selection.text) if input.keys.copy?
      bar.add_to(frame.overlay)
      frame.showing(@marks)
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
