# frozen_string_literal: true

# The outline as drawn and clicked: its band under the header with one row
# per heading (indented by its level, with its tasks' count, the selected
# one highlighted), which row a press lands on, and where a row jumps to.

require_relative "anchor"
require_relative "draw_list"
require_relative "help_panel"
require_relative "input"
require_relative "outline_rows"
require_relative "page_in_view"
require_relative "scroll_spot"
require_relative "styles"
require_relative "theme"

module Shipinel
  # See the file comment.
  class OutlinePanel
    # Pixels each level below the first moves a row right.
    INDENT = 16.0
    # A press on no row, or no press.
    NONE = -1
    # A press outside the panel.
    OUTSIDE = -2

    # @rbs @outline: Outline
    # @rbs @page: PageInView
    # @rbs @rows: OutlineRows
    # @rbs @style: TextStyle

    #: (Outline outline, PageInView page, TextStyle style) -> void
    def initialize(outline, page, style)
      @outline = outline
      @page = page
      @rows = OutlineRows.new(outline.selected, page, style.line_height)
      @style = style
    end

    # The row of the section the window is in (0 above the first heading).
    #: () -> Integer
    def current
      [@rows.anchors.above(@page.view.offset), 0].max
    end

    # `position` kept between the first row and the last.
    #: (Integer position) -> Integer
    def within(position)
      last = @rows.anchors.size - 1
      position.negative? || last.negative? ? 0 : [position, last].min
    end

    # The row a press of this frame's `input` landed on, NONE (no press, or
    # past the last row) or OUTSIDE the panel.
    #: (Input input) -> Integer
    def picked(input)
      at = input.at
      return NONE unless input.pressed?

      @rows.band.contains?(at) ? @rows.row_at(at.top) : OUTSIDE
    end

    # The heading of row `position` (ScrollSpot.none for none).
    #: (Integer position) -> ScrollSpot
    def spot_at(position)
      position.negative? ? ScrollSpot.none : ScrollSpot.of(@rows.anchors.at(position))
    end

    # A row's text: "Goal 1 — Billing · 3 of 7", or the title alone
    # without tasks.
    #: (Anchor anchor) -> String
    def self.label_of(anchor)
      title = anchor.title
      tasks = anchor.progress.count_text
      tasks.empty? ? title : "#{title} · #{tasks}"
    end

    # Into the overlay, while the outline is open; the help instead while
    # that is.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      @outline.help? ? HelpPanel.new(@page, @style).add_to(overlay) : add_outline(overlay)
    end

    private

    #: (DrawList overlay) -> void
    def add_outline(overlay)
      return unless @outline.open?

      add_band(overlay)
      @rows.shown.times { |row| add_row(overlay, @rows.top_row + row) }
      add_empty(overlay) if @rows.anchors.empty?
    end

    # The band, with a thin rule along its bottom to part it from the page.
    #: (DrawList overlay) -> void
    def add_band(overlay)
      overlay.add(Box.new(@rows.band, Theme::Progress::BAND))
      overlay.add(Box.new(@rows.rule, Theme::Progress::TRACK))
    end

    #: (DrawList overlay, Integer position) -> void
    def add_row(overlay, position)
      anchors = @rows.anchors
      return if position >= anchors.size

      rect = @rows.rect_of(position)
      overlay.add(Box.new(rect, Theme::Selected::BACKGROUND)) if position == @outline.selected
      overlay.add(TextRun.new(OutlinePanel.label_of(anchors.at(position)), rect.indented(indent_of(position)), @style))
    end

    # The margin, and INDENT for each level below the first.
    #: (Integer position) -> Float
    def indent_of(position)
      Theme::Spacing::MARGIN + ((@rows.anchors.level_at(position) - 1) * INDENT)
    end

    # A plan without headings says so in its one row.
    #: (DrawList overlay) -> void
    def add_empty(overlay)
      muted = @style.with_color(Theme::Ink::MUTED)
      overlay.add(TextRun.new("No headings in this plan", @rows.rect_of(0).indented(Theme::Spacing::MARGIN), muted))
    end
  end
end
