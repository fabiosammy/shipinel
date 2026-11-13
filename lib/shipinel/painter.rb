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
      @clicked = frame.pressed
      @hand = false
    end

    # The checkbox or link clicked this frame, if any (the last one wins;
    # Space on the focused checkbox counts as a click on it).
    #: () -> DrawCommand?
    def paint
      paint_marks
      paint_contents
      paint_overlays
      @screen.use_hand_cursor(@hand)
      @clicked
    end

    private

    # Selected text gets a background, drawn before (under) the page. Only
    # page text: the overlay's is never selected.
    #: () -> void
    def paint_selection
      return unless @frame.selection.active?

      @frame.content_size.times { |position| mark_selected(@frame.content_at(position)) }
    end

    # The find bar's matches get a background, the one it is on brighter;
    # then the selection.
    #: () -> void
    def paint_marks
      search = @frame.marks.search
      search.matches.pieces.times { |piece| mark_found(search, piece) }
      paint_selection
    end

    #: (Search search, Integer piece) -> void
    def mark_found(search, piece)
      view = @frame.view
      area = search.matches.rect_at(piece).up(view.shift)
      @screen.draw_rect(area, search.color_of(piece)) if view.shows?(area)
      nil
    end

    #: (DrawCommand command) -> void
    def mark_selected(command)
      view = @frame.view
      area = command.rect.up(view.shift)
      return unless view.shows?(area) && Selection.highlights?(@frame.selection, command)

      @screen.draw_rect(area, Theme::Selected::BACKGROUND)
      nil
    end

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
      point_at(command, area) if command.is_a?(Clickable) && @frame.reachable?(area)
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

    # A release that ends a text selection clicks nothing.
    #: (DrawCommand command, Rect area) -> void
    def point_at(command, area)
      pointer = @screen.pointer_on(area)
      @hand ||= pointer != :away
      @clicked = command if pointer == :clicked && !@frame.selection.released?
      nil
    end
  end
end
