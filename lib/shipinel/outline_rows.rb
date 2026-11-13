# frozen_string_literal: true

# Where the outline's rows go: a band under the header, one row per
# heading, as many as fit in seven tenths of the page area, scrolled to
# keep the selected row in view.

require_relative "anchor"
require_relative "geometry"
require_relative "page_in_view"

module Shipinel
  # See the file comment.
  class OutlineRows
    # Pixels above the first row and below the last.
    PADDING = 8.0
    # Past the last row.
    NONE = -1

    # @rbs @selected: Integer
    # @rbs @page: PageInView
    # @rbs @line_height: Float

    #: (Integer selected, PageInView page, Float line_height) -> void
    def initialize(selected, page, line_height)
      @selected = selected
      @page = page
      @line_height = line_height
    end

    #: () -> AnchorList
    def anchors
      @page.content.anchors
    end

    # How many rows are shown: one per heading, as many as fit.
    #: () -> Integer
    def shown
      [room, wanted].min
    end

    # The first row shown: the selected one stays in view.
    #: () -> Integer
    def top_row
      @selected >= shown ? @selected - shown + 1 : 0
    end

    # The panel's area in the window.
    #: () -> Rect
    def band
      area = @page.view
      Rect.new(0.0, area.top, area.width, band_height)
    end

    # A thin rule along the band's bottom, parting it from the page.
    #: () -> Rect
    def rule
      area = @page.view
      Rect.new(0.0, area.top + band_height - 1.0, area.width, 1.0)
    end

    # Row `position` (of the anchors) in the window.
    #: (Integer position) -> Rect
    def rect_of(position)
      area = @page.view
      Rect.new(0.0, area.top + PADDING + ((position - top_row) * @line_height), area.width, @line_height)
    end

    # The row at `top` (a window position inside the band), or NONE past
    # the last one.
    #: (Float top) -> Integer
    def row_at(top)
      row = top_row + ((top - @page.view.top - PADDING) / @line_height).floor
      row < anchors.size ? row : NONE
    end

    private

    #: () -> Float
    def band_height
      (shown * @line_height) + (PADDING * 2)
    end

    # How many rows fit in seven tenths of the page area: at least one.
    #: () -> Integer
    def room
      [(((@page.view.height * 0.7) - (PADDING * 2)) / @line_height).floor, 1].max
    end

    # One row per heading; one for the "no headings" line.
    #: () -> Integer
    def wanted
      anchors.empty? ? 1 : anchors.size
    end
  end
end
