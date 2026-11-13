# frozen_string_literal: true

# The keyboard focus: the checkbox Tab moved to (Shift+Tab back, round the
# ends), which Space ticks as a click would and Escape lets go. It is kept
# by the task's line index, so it survives the page being laid out again;
# the first Tab starts at the first checkbox in view.

require_relative "draw_list"
require_relative "focus_steps"
require_relative "keyboard"
require_relative "page_in_view"
require_relative "scroll_spot"

module Shipinel
  # See the file comment. A new value replaces it whenever it changes.
  class Focus
    # The focused task's line index; -1 for none.
    attr_reader :line #: Integer

    # @rbs @pressed: bool

    #: (Integer line, bool pressed) -> void
    def initialize(line, pressed)
      @line = line
      @pressed = pressed
    end

    #: () -> Focus
    def self.none
      Focus.new(-1, false)
    end

    # Space was pressed on the focused checkbox this frame.
    #: () -> bool
    def pressed?
      @pressed
    end

    # The focus after this frame's keys, on `page`.
    #: (FocusKeys keys, PageInView page) -> Focus
    def after(keys, page)
      keys.focus_after(@line, page)
    end

    # The focused checkbox of `content`, when Space pressed it this frame
    # (a click on it, for App#act).
    #: (DrawList content) -> DrawCommand?
    def pressed_in(content)
      position = FocusSteps.position_of_line(content, @line)
      @pressed && position >= 0 ? content.at(position) : nil
    end

    # Where the window goes to show the focused checkbox (PageInView#aim_at).
    #: (PageInView page) -> ScrollSpot
    def aim(page)
      page.aim_at(@line)
    end

    # A ring around the focused checkbox, into `overlay`, while all of it
    # is in view.
    #: (DrawList overlay, PageInView page) -> void
    def ring_into(overlay, page)
      page.ring_at(overlay, @line)
    end

    # Same task, and Space pressed or not.
    #: (Focus other) -> bool
    def same_as?(other)
      @line == other.line && @pressed == other.pressed?
    end
  end
end
