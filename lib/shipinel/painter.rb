# frozen_string_literal: true

# Draws a laid-out page onto the screen, scrolled up by an offset, reports
# which checkbox or link was clicked, and shows the pointing-hand cursor
# while the mouse is over one of them.

require_relative "draw_list"
require_relative "screen"
require_relative "task_toggler"

module Shipinel
  # See the file comment. One Painter paints one frame.
  class Painter
    # @rbs @screen: Screen
    # @rbs @scroll: Float
    # @rbs @clicked: DrawCommand?
    # @rbs @hand: bool

    #: (Screen screen, Float scroll) -> void
    def initialize(screen, scroll)
      @screen = screen
      @scroll = scroll
      @clicked = nil
      @hand = false
    end

    # The checkbox or link clicked this frame, if any (the last one wins).
    #: (DrawList page) -> DrawCommand?
    def paint(page)
      page.size.times { |position| paint_command(page.at(position)) }
      @screen.use_hand_cursor(@hand)
      @clicked
    end

    private

    #: (DrawCommand command) -> void
    def paint_command(command)
      area = command.rect.up(@scroll)
      draw(command, area)
      point_at(command, area) if command.is_a?(Clickable)
      nil
    end

    # Each branch reads its kind's fields here (.reek.yml, as Layout).
    #: (DrawCommand command, Rect area) -> void
    def draw(command, area)
      case command
      when TextRun then @screen.draw_text(command.text, area.corner, command.style)
      when Box then @screen.draw_rect(area, command.color)
      when Checkbox then @screen.draw_checkbox(area, command.click.checked?)
      end
      nil
    end

    #: (DrawCommand command, Rect area) -> void
    def point_at(command, area)
      pointer = @screen.pointer_on(area)
      @hand ||= pointer != :away
      @clicked = command if pointer == :clicked
      nil
    end
  end
end
