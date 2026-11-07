# frozen_string_literal: true

# Draws a frame onto the screen: the document scrolled, skipping what the
# window does not show, then the overlay on top. Reports which checkbox or
# link was clicked, and shows the pointing-hand cursor while the mouse is
# over one of them. Nothing under the progress header can be clicked.

require_relative "draw_list"
require_relative "frame"
require_relative "screen"
require_relative "task_toggler"

module Shipinel
  # See the file comment. One Painter paints one frame.
  class Painter
    # @rbs @screen: Screen
    # @rbs @frame: Frame
    # @rbs @clicked: DrawCommand?
    # @rbs @hand: bool

    #: (Screen screen, Frame frame) -> void
    def initialize(screen, frame)
      @screen = screen
      @frame = frame
      @clicked = nil
      @hand = false
    end

    # The checkbox or link clicked this frame, if any (the last one wins).
    #: () -> DrawCommand?
    def paint
      paint_contents
      paint_overlays
      @screen.use_hand_cursor(@hand)
      @clicked
    end

    private

    #: () -> void
    def paint_contents
      @frame.content_size.times { |position| paint_content(@frame.content_at(position)) }
    end

    # On top of the content.
    #: () -> void
    def paint_overlays
      @frame.overlay_size.times { |position| paint_overlay(@frame.overlay_at(position)) }
    end

    #: (DrawCommand command) -> void
    def paint_content(command)
      view = @frame.view
      area = command.rect.up(view.shift)
      return unless view.shows?(area)

      draw(command, area)
      point_at(command, area) if command.is_a?(Clickable) && area.top >= view.top
    end

    # The overlay is in window position already.
    #: (DrawCommand command) -> void
    def paint_overlay(command)
      draw(command, command.rect)
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
