# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/table_layout"

class ColumnGridTest < Minitest::Test
  def fit(naturals, available) = Shipinel::ColumnGrid.fit(naturals, available)

  def test_a_table_that_fits_keeps_its_widths
    assert_equal [10.0, 90.0], fit([10.0, 90.0], 100.0)
  end

  def test_narrow_columns_keep_their_width_and_wide_ones_share_the_rest
    assert_equal [20.0, 40.0, 40.0], fit([20.0, 300.0, 500.0], 100.0)
  end

  def test_all_wide_columns_split_evenly
    assert_equal [50.0, 50.0], fit([400.0, 300.0], 100.0)
  end

  def test_positions
    grid = Shipinel::ColumnGrid.new([20.0, 30.0], 16.0)

    assert_equal [16.0, 36.0, 66.0, 50.0], [grid.left(0), grid.right(0), grid.right(1), grid.width]
  end
end
