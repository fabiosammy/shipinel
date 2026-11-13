# frozen_string_literal: true

# Checkboxes in a draw list, by their task line, and the bars of the
# keyboard focus's ring.

require_relative "draw_list"
require_relative "geometry"
require_relative "theme"

module Shipinel
  # Checkboxes in a draw list, and the ring's bars.
  module FocusSteps
    # The draw list position of the checkbox of task `line`, or -1.
    #: (DrawList content, Integer line) -> Integer
    def self.position_of_line(content, line)
      position = 0
      size = content.size
      position += 1 while position < size && (line.negative? || FocusSteps.line_of(content.at(position)) != line)
      position >= size ? -1 : position
    end

    # Whether `command` is a checkbox at or below `top`.
    #: (DrawCommand command, Float top) -> bool
    def self.box_below?(command, top)
      FocusSteps.line_of(command) >= 0 && command.rect.top >= top
    end

    # A checkbox's task line index, -1 for any other command.
    #: (DrawCommand command) -> Integer
    def self.line_of(command)
      case command
      when Checkbox then command.click.line_index
      else -1
      end
    end

    # Four thin bars just outside `box`, a window position.
    #: (DrawList overlay, Rect box) -> void
    def self.ring(overlay, box)
      reach = Theme::Focus::GAP + Theme::Focus::WIDTH
      across = 2 * reach
      outer = Rect.new(box.left - reach, box.top - reach, box.width + across, box.height + across)
      FocusSteps.rows(overlay, outer)
      FocusSteps.sides(overlay, outer)
    end

    # The ring's top and bottom bars: `outer` less all but its first or
    # last few pixels.
    #: (DrawList overlay, Rect outer) -> void
    def self.rows(overlay, outer)
      cut = outer.height - Theme::Focus::WIDTH
      overlay.add(Box.new(outer.shortened(cut), Theme::Focus::RING))
      overlay.add(Box.new(outer.below(cut), Theme::Focus::RING))
    end

    # Its left and right bars.
    #: (DrawList overlay, Rect outer) -> void
    def self.sides(overlay, outer)
      width = outer.width
      overlay.add(Box.new(outer.left_part(Theme::Focus::WIDTH / width), Theme::Focus::RING))
      overlay.add(Box.new(outer.indented(width - Theme::Focus::WIDTH), Theme::Focus::RING))
    end
  end
end
