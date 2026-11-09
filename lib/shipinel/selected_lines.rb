# frozen_string_literal: true

# The words of a selection as text to copy: one line for each line they
# are drawn on.

require_relative "draw_list"

module Shipinel
  # The words of a selection gathered into lines: pieces drawn on the same
  # line top join, and a new top starts a new line.
  class SelectedLines
    # @rbs @lines: Array[String]
    # @rbs @line: String
    # @rbs @top: Float

    #: () -> void
    def initialize
      @lines = []
      @line = ""
      @top = -1.0
    end

    # Adds `command` to `lines` when it is text the selection covers.
    #: (SelectedLines lines, DrawCommand command, Selection selection) -> void
    def self.take(lines, command, selection)
      rect = command.rect
      lines.add(rect.top, command.text) if command.is_a?(TextRun) && selection.covers?(rect)
      nil
    end

    # A piece of text drawn at `top`.
    #: (Float top, String text) -> void
    def add(top, text)
      next_line(top)
      @line = "#{@line}#{text}"
      nil
    end

    #: () -> String
    def text
      next_line(-1.0)
      @lines.join("\n")
    end

    private

    # A piece on another line ends the one so far.
    #: (Float top) -> void
    def next_line(top)
      return if top == @top

      @lines << @line.rstrip unless @top.negative?
      @line = ""
      @top = top
      nil
    end
  end
end
