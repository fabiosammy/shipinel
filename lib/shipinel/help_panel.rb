# frozen_string_literal: true

# The help that ? or F1 opens over the page: what Shipinel is, in a line,
# and every key and click with what it does. It covers the page area under
# the header; rows past its bottom are left out.

require_relative "draw_list"
require_relative "geometry"
require_relative "page_in_view"
require_relative "styles"
require_relative "theme"
require_relative "version"

module Shipinel
  # See the file comment.
  class HelpPanel
    # Pixels above the first row.
    PADDING = 8.0
    # The keys' column, in text sizes (the descriptions start after it).
    KEY_COLUMN = 8.0

    # @rbs @page: PageInView
    # @rbs @style: TextStyle

    #: (PageInView page, TextStyle style) -> void
    def initialize(page, style)
      @page = page
      @style = style
    end

    # What the help says: a title, then "keys|what they do" rows.
    #: () -> Array[String]
    def self.lines
      ["Shipinel #{VERSION}: your week's plan, kept in view", "",
       "Your editor|Edits the plan; Shipinel follows",
       "Click a box|Tick or untick a task", "Tab, Shift+Tab|Move the focus ring between tasks",
       "Space|Tick the task with the focus ring", "u|Undo the last tick",
       "j, k, arrows|Scroll a line", "Page Up / Down|Scroll a window", "Home / End|Go to the top / the end",
       "g|Sections: jump to one", "Ctrl+F|Find (Enter: next, Escape: close)",
       "Drag, Ctrl+A|Select text", "Ctrl+C|Copy the selection", "+, -, 0|Text size",
       "h|Hide or show the header", "? or F1|This help (Escape or a click closes it)"]
    end

    # Into the overlay.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      overlay.add(Box.new(@page.view.area, Theme::Surface::BACKGROUND))
      lines = HelpPanel.lines
      [lines.size, room].min.times { |row| add_line(overlay, lines[row], row) }
    end

    private

    # How many rows fit in the page area.
    #: () -> Integer
    def room
      ((@page.view.height - PADDING) / @style.line_height).floor
    end

    # Row `row`: its key in the accent color and what it does after it.
    #: (DrawList overlay, String line, Integer row) -> void
    def add_line(overlay, line, row)
      rect = row_rect(row)
      parts = line.split("|", -1)
      overlay.add(TextRun.new(parts[0].to_s, rect, @style.with_color(Theme::Accent::LINK)))
      add_does(overlay, parts, rect)
    end

    # What the keys do, after the keys' column (nothing for a title).
    #: (DrawList overlay, Array[String] parts, Rect rect) -> void
    def add_does(overlay, parts, rect)
      return if parts.size < 2

      overlay.add(TextRun.new(parts[1].to_s, rect.indented(@style.size * KEY_COLUMN), @style))
    end

    #: (Integer row) -> Rect
    def row_rect(row)
      tall = @style.line_height
      area = @page.view
      Rect.new(Theme::Spacing::MARGIN, area.top + PADDING + (row * tall), area.width, tall)
    end
  end
end
