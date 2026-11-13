# frozen_string_literal: true

# The panel under the header: the outline, the list of the plan's sections
# that `g` opens to jump to one, or the help that ? or F1 opens. In the
# outline the section the window is in is selected at first; j/k or the
# arrows move the selection, Enter or a click on a row jumps there and
# closes it, and g, Escape or a click outside close it. The help closes on
# ?, F1, Escape or a click.

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
    # @rbs @help: bool

    #: (bool open, Integer selected, Integer target, bool help) -> void
    def initialize(open, selected, target, help)
      @open = open
      @selected = selected
      @target = target
      @help = help
    end

    #: () -> Outline
    def self.none
      Outline.new(false, 0, STAY, false)
    end

    # The outline is open.
    #: () -> bool
    def open?
      @open
    end

    # The help is open.
    #: () -> bool
    def help?
      @help
    end

    # Either is open, and takes the keys.
    #: () -> bool
    def shown?
      @open || @help
    end

    # The panel after this frame's input, shown as `panel`.
    #: (Input input, OutlinePanel panel) -> Outline
    def after(input, panel)
      keys = input.keys.for_outline
      return helped(keys, input) if @help || keys.help?

      listed(keys, input, panel)
    end

    # Where the window goes for this frame's jump (ScrollSpot.none for
    # none).
    #: (OutlinePanel panel) -> ScrollSpot
    def spot(panel)
      panel.spot_at(@target)
    end

    # Same panel, same selection, same jump.
    #: (Outline other) -> bool
    def same_as?(other)
      key == other.key
    end

    # What tells two outlines apart, as text.
    #: () -> String
    def key
      "#{@open} #{@help} #{@selected} #{@target}"
    end

    private

    # The help after this frame: ? or F1 open it (closing the outline) or
    # close it, and so do Escape and a click.
    #: (OutlineKeys keys, Input input) -> Outline
    def helped(keys, input)
      closing = keys.ends_help? || input.pressed?
      Outline.new(false, 0, STAY, @help ? !closing : true)
    end

    # The outline after this frame's keys and clicks.
    #: (OutlineKeys keys, Input input, OutlinePanel panel) -> Outline
    def listed(keys, input, panel)
      return toggled(panel) if keys.toggle?
      return Outline.none if !@open || keys.close?

      target = OutlineKeys.target(keys, @selected, panel.picked(input))
      Outline.new(target == STAY, panel.within(@selected + keys.step), target, false)
    end

    # g: closes an open outline, or opens one on the section in view.
    #: (OutlinePanel panel) -> Outline
    def toggled(panel)
      @open ? Outline.none : Outline.new(true, panel.current, STAY, false)
    end
  end
end
