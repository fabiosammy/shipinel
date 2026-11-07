# frozen_string_literal: true

# Draw commands: what Layout decides and Painter draws, positioned on the
# page (not yet scrolled). A checkbox keeps its task's line index, so a
# click maps back to that source line.

require_relative "geometry"
require_relative "task_toggler"
require_relative "theme"

module Shipinel
  # The base of every draw command: the area of the page it covers. Like
  # Markdown::Block, subclasses only add data, so a DrawList compiles to one
  # typed array under Spinel.
  class DrawCommand
    attr_reader :rect #: Rect

    #: (Rect rect) -> void
    def initialize(rect)
      @rect = rect
    end
  end

  # Text in one style; drawn from the top-left corner of its rect.
  class TextRun < DrawCommand
    attr_reader :text #: String
    attr_reader :style #: TextStyle

    #: (String text, Rect rect, TextStyle style) -> void
    def initialize(text, rect, style)
      super(rect)
      @text = text
      @style = style
    end
  end

  # A filled rectangle.
  class Box < DrawCommand
    attr_reader :color #: Integer

    #: (Rect rect, Integer color) -> void
    def initialize(rect, color)
      super(rect)
      @color = color
    end
  end

  # A task checkbox, with the click a user would make on it: its task's
  # line index and the state the file had when it was laid out.
  class Checkbox < DrawCommand
    attr_reader :click #: TaskClick

    #: (Rect rect, TaskClick click) -> void
    def initialize(rect, click)
      super(rect)
      @click = click
    end
  end

  # The commands of one laid-out page, in drawing order, and its height.
  class DrawList
    attr_reader :height #: Float

    # @rbs @commands: Array[DrawCommand]

    #: () -> void
    def initialize
      @commands = []
      @height = 0.0
    end

    #: (DrawCommand command) -> void
    def add(command)
      @commands << command
      nil
    end

    #: () -> Integer
    def size
      @commands.size
    end

    #: (Integer position) -> DrawCommand
    def at(position)
      @commands[position]
    end

    #: (Float height) -> DrawList
    def finish(height)
      @height = height
      self
    end
  end
end
