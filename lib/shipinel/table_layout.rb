# frozen_string_literal: true

# Lays a table out on the Flow: columns sized to their content and shrunk to
# fit the page, cells side by side with their text wrapped inside the
# column, header rows in bold with a rule under them, and a faint line
# between the other rows.

require_relative "column_grid"
require_relative "draw_list"
require_relative "geometry"
require_relative "markdown/block"
require_relative "theme"

module Shipinel
  # See the file comment. Cells come as Markdown::Table keeps them: one
  # string, cells joined by Table::SEPARATOR, row after row, `columns` per
  # row.
  class TableLayout
    # @rbs @flow: Flow
    # @rbs @cells: Array[String]
    # @rbs @columns: Integer
    # @rbs @header_rows: Integer

    #: (Flow flow, String cells, Integer columns, Integer header_rows) -> void
    def initialize(flow, cells, columns, header_rows)
      @flow = flow
      @cells = cells.split(Markdown::Table::SEPARATOR, -1)
      @columns = columns
      @header_rows = header_rows
    end

    # Leaves the flow under the table, wrapping at the page edge again.
    #: () -> void
    def place
      page_right = @flow.right
      grid = grid_within(page_right)
      (@cells.size / @columns).times { |row| underline_row(row, grid, place_cells(row, grid)) }
      @flow.restart_at(@flow.top, page_right)
    end

    private

    #: (Float page_right) -> ColumnGrid
    def grid_within(page_right)
      naturals = NaturalWidths.new(@flow, @cells, @columns).widths
      ColumnGrid.new(ColumnGrid.fit(naturals, page_right - Theme::Spacing::MARGIN), Theme::Spacing::MARGIN)
    end

    #: () -> Float
    def padding
      @flow.styles.cell_padding
    end

    # Each cell starts at the row's top; returns where the tallest ended.
    #: (Integer row, ColumnGrid grid) -> Float
    def place_cells(row, grid)
      top = @flow.top
      style = row_style(row)
      bottoms = Array.new(@columns) do |column|
        place_cell(TableCell.new(cell_text(row, column), column, style), grid, top)
      end
      bottoms.max.to_f
    end

    #: (Integer row, Integer column) -> String
    def cell_text(row, column)
      @cells[(row * @columns) + column].to_s
    end

    #: (Integer row) -> TextStyle
    def row_style(row)
      body = @flow.styles.body
      row < @header_rows ? body.with_font(Theme::FontSlot::BOLD) : body
    end

    # Returns where the cell's text ended.
    #: (TableCell cell, ColumnGrid grid, Float top) -> Float
    def place_cell(cell, grid, top)
      column = cell.column
      @flow.restart_at(top, grid.right(column) - padding)
      @flow.text(cell.text, grid.left(column) - Theme::Spacing::MARGIN + padding, cell.style)
      @flow.top
    end

    # The rule under the header, a faint line under every other row.
    #: (Integer row, ColumnGrid grid, Float bottom) -> void
    def underline_row(row, grid, bottom)
      color = row + 1 == @header_rows ? Theme::Surface::RULE : Theme::Surface::CODE_BACKGROUND
      @flow.add(Box.new(Rect.new(grid.left(0), bottom, grid.width, 1.0), color))
      @flow.restart_at(bottom + padding, @flow.right)
    end
  end
end
