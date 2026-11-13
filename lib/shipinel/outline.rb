# frozen_string_literal: true

# The outline: the list of the plan's sections that `g` opens under the
# header, to jump to one. The section the window is in is selected at
# first; j/k or the arrows move the selection, Enter or a click on a row
# jumps there and closes it, and g, Escape or a click outside close it.

require_relative "input"
require_relative "keyboard"
require_relative "outline_panel"
require_relative "scroll_spot"

module Shipinel
  # See the file comment. A new value replaces it whenever it changes.
  class Outline
    # Not jumping this frame.
    STAY = -1

    # The selected row (the heading's position in the page's anchors).
    attr_reader :selected #: Integer
    # The row jumped to this frame, STAY, or OutlinePanel::OUTSIDE when a
    # click outside closed it.
    attr_reader :target #: Integer

    # @rbs @open: bool

    #: (bool open, Integer selected, Integer target) -> void
    def initialize(open, selected, target)
      @open = open
      @selected = selected
      @target = target
    end

    #: () -> Outline
    def self.none
      Outline.new(false, 0, STAY)
    end

    #: () -> bool
    def open?
      @open
    end

    # The outline after this frame's input, shown as `panel`.
    #: (Input input, OutlinePanel panel) -> Outline
    def after(input, panel)
      keys = input.keys.for_outline
      return toggled(panel) if keys.toggle?
      return Outline.none if !@open || keys.close?

      target = Outline.target_of(@selected, keys, panel.picked(input))
      Outline.new(target == STAY, panel.within(@selected + keys.step), target)
    end

    # Where this frame's input jumps: the row clicked, OUTSIDE for a click
    # outside the panel, `selected` on Enter, else STAY.
    #: (Integer selected, OutlineKeys keys, Integer picked) -> Integer
    def self.target_of(selected, keys, picked)
      return picked if picked >= 0 || picked == OutlinePanel::OUTSIDE

      keys.jump? ? selected : STAY
    end

    # Where the window goes for this frame's jump (ScrollSpot.none for
    # none).
    #: (OutlinePanel panel) -> ScrollSpot
    def spot(panel)
      panel.spot_at(@target)
    end

    # Same rows, same selection, same jump.
    #: (Outline other) -> bool
    def same_as?(other)
      @open == other.open? && @selected == other.selected && @target == other.target
    end

    private

    # g: closes an open outline, or opens one on the section in view.
    #: (OutlinePanel panel) -> Outline
    def toggled(panel)
      @open ? Outline.none : Outline.new(true, panel.current, STAY)
    end
  end
end
