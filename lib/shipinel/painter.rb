# frozen_string_literal: true

# Draws a laid-out page onto the screen, scrolled up by an offset, and
# reports a checkbox click as the TaskClick to apply to the file.

require_relative "draw_list"
require_relative "screen"
require_relative "task_toggler"

module Shipinel
  # See the file comment. Stateless: the screen and the page come in each
  # frame.
  module Painter
    # At most one checkbox can be clicked in a frame; the last one wins.
    #: (Screen screen, DrawList page, Float scroll) -> TaskClick?
    def self.paint(screen, page, scroll)
      # @type var clicked: TaskClick?
      clicked = nil
      position = 0
      while position < page.size
        clicked = paint_command(screen, page.at(position), scroll) || clicked
        position += 1
      end
      clicked
    end

    #: (Screen screen, DrawCommand command, Float scroll) -> TaskClick?
    def self.paint_command(screen, command, scroll)
      area = command.rect.up(scroll)
      return clicked(screen, area, command.click) if command.is_a?(Checkbox)

      draw(screen, command, area)
      nil
    end

    #: (Screen screen, DrawCommand command, Rect area) -> void
    def self.draw(screen, command, area)
      case command
      when TextRun then screen.draw_text(command.text, area.corner, command.style)
      when Box then screen.draw_rect(area, command.color)
      end
      nil
    end

    # The click, if the checkbox drawn in `area` was clicked this frame.
    #: (Screen screen, Rect area, TaskClick click) -> TaskClick?
    def self.clicked(screen, area, click)
      screen.checkbox_clicked?(area, click.checked?) ? click : nil
    end
  end
end
