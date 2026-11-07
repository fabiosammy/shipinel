# frozen_string_literal: true

# Where a table's columns go: how wide each wants to be, how they share a
# page too narrow for all of them, and the cell TableLayout places in one.

require_relative "theme"

module Shipinel
  # Where a table's columns go. Each column wants its widest cell's width;
  # when the table is wider than the page, narrow columns keep their width
  # and the wide ones share what is left equally.
  class ColumnGrid
    # @rbs @lefts: Array[Float]
    # @rbs @widths: Array[Float]

    #: (Array[Float] naturals, Float available) -> Array[Float]
    def self.fit(naturals, available)
      share = fair_share(naturals, available)
      naturals.map { |width| [width, share].min }
    end

    # Starts from an equal split; each round, the columns narrower than the
    # share give their unused room to the others. Columns only ever leave
    # the wide group, so as many rounds as columns always settle it.
    #: (Array[Float] naturals, Float available) -> Float
    def self.fair_share(naturals, available)
      columns = naturals.size
      share = available / columns
      columns.times { share = share_after_round(naturals, available, share) }
      share
    end

    #: (Array[Float] naturals, Float available, Float share) -> Float
    def self.share_after_round(naturals, available, share)
      narrow = naturals.select { |width| width < share }
      wide = naturals.size - narrow.size
      wide.zero? ? share : (available - total(narrow)) / wide
    end

    #: (Array[Float] widths) -> Float
    def self.total(widths)
      sum = 0.0
      widths.each { |width| sum += width }
      sum
    end

    #: (Array[Float] widths, Float left) -> void
    def initialize(widths, left)
      @widths = widths
      @lefts = []
      widths.each do |width|
        @lefts << left
        left += width
      end
    end

    #: (Integer column) -> Float
    def left(column)
      @lefts[column]
    end

    #: (Integer column) -> Float
    def right(column)
      @lefts[column] + @widths[column]
    end

    #: () -> Float
    def width
      ColumnGrid.total(@widths)
    end
  end

  # One cell to place: its text, its column, and how it is drawn.
  class TableCell
    attr_reader :text #: String
    attr_reader :column #: Integer
    attr_reader :style #: TextStyle

    #: (String text, Integer column, TextStyle style) -> void
    def initialize(text, column, style)
      @text = text
      @column = column
      @style = style
    end
  end

  # What each column of a table wants: its widest cell on one line, with
  # padding on both sides.
  class NaturalWidths
    # @rbs @flow: Flow
    # @rbs @cells: Array[String]
    # @rbs @columns: Integer

    #: (Flow flow, Array[String] cells, Integer columns) -> void
    def initialize(flow, cells, columns)
      @flow = flow
      @cells = cells
      @columns = columns
    end

    #: () -> Array[Float]
    def widths
      widths = Array.new(@columns, 2 * @flow.styles.cell_padding)
      @cells.size.times { |position| widen(widths, position) }
      widths
    end

    private

    #: (Array[Float] widths, Integer position) -> void
    def widen(widths, position)
      column = position % @columns
      styles = @flow.styles
      wanted = @flow.fonts.text_width(@cells[position].to_s, styles.body) + (2 * styles.cell_padding)
      widths[column] = wanted if wanted > widths[column]
      nil
    end
  end
end
