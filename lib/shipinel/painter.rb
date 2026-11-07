# frozen_string_literal: true

# Draws a laid-out page onto the screen, scrolled up by an offset, and
# reports which checkbox or link was clicked.

require_relative "draw_list"
require_relative "screen"
require_relative "task_toggler"

module Shipinel
  # See the file comment. Stateless: the screen and the page come in each
  # frame.
  module Painter
    # At most one thing can be clicked in a frame; the last one wins.
    #: (Screen screen, DrawList page, Float scroll) -> DrawCommand?
    def self.paint(screen, page, scroll)
      # @type var clicked: DrawCommand?
      clicked = nil
      position = 0
      while position < page.size
        clicked = paint_command(screen, page.at(position), scroll) || clicked
        position += 1
      end
      clicked
    end

    # The command itself when it is a checkbox or link clicked this frame.
    #: (Screen screen, DrawCommand command, Float scroll) -> DrawCommand?
    def self.paint_command(screen, command, scroll)
      area = command.rect.up(scroll)
      draw(screen, command, area)
      clicked?(screen, command, area) ? command : nil
    end

    #: (Screen screen, DrawCommand command, Rect area) -> void
    def self.draw(screen, command, area)
      case command
      when TextRun then screen.draw_text(command.text, area.corner, command.style)
      when Box then screen.draw_rect(area, command.color)
      end
      nil
    end

    # raygui draws a checkbox and reports its click in one call.
    #: (Screen screen, DrawCommand command, Rect area) -> bool
    def self.clicked?(screen, command, area)
      case command
      when Checkbox then screen.checkbox_clicked?(area, command.click.checked?)
      when LinkArea then screen.clicked_in?(area)
      else false
      end
    end
  end
end
