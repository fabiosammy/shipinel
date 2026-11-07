# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/layout"
require_relative "../../lib/shipinel/markdown/parser"

# Tables from Markdown lines to draw commands. Same measures as LayoutTest:
# size 20, margin 16, a font 0.5 * size wide per character; cells are
# padded by 8 on each side.
class TableTest < Minitest::Test
  STYLES = Shipinel::Styles.new(20.0)

  def summary(source)
    blocks = Shipinel::Markdown::Parser.parse(source)
    Array.new(blocks.size) { |position| describe(blocks.at(position)) }
  end

  def describe(block)
    return "#{block.line_index}: p #{block.text}" unless block.is_a?(Shipinel::Markdown::Table)

    cells = block.text.split(Shipinel::Markdown::Table::SEPARATOR, -1).join("|")
    "#{block.line_index}: table #{block.columns}x#{block.rows} header #{block.header_rows} #{cells}"
  end

  def arrange(source, width = 400.0)
    Shipinel::Layout.new(fake_font_set(source), STYLES, width).arrange(Shipinel::Markdown::Parser.parse(source), [])
  end

  def commands(source, width = 400.0)
    page = arrange(source, width)
    Array.new(page.size) { |position| page.at(position) }.grep(Shipinel::TextRun).map { |run| text(run) }
  end

  def text(run)
    "text #{run.text.inspect} at #{run.rect.left.round(1)},#{run.rect.top.round(1)} slot #{run.style.font_slot}"
  end

  def test_table_rows_become_one_table
    assert_equal ["0: p antes", "1: table 2x3 header 1 Goal|State|Drata|12|Twingate|", "5: p depois"],
                 summary("antes\n| Goal | State |\n|---|:-:|\n| Drata | 12 |\n| Twingate |\ndepois")
  end

  def test_extra_cells_are_cut_to_the_first_rows_count
    assert_equal ["0: table 1x2 header 0 a|b"], summary("| a |\n| b | c |")
  end

  def test_a_blank_line_ends_a_table
    assert_equal ["0: table 1x1 header 0 a", "2: table 1x1 header 0 b"], summary("| a |\n\n| b |")
  end

  def test_table_cells_side_by_side_with_a_bold_header
    texts = commands("| a | b |\n|---|---|\n| c | d |")

    assert_equal ["text \"a\" at 24.0,16.0 slot 2", "text \"b\" at 50.0,16.0 slot 2",
                  "text \"c\" at 24.0,51.0 slot 0", "text \"d\" at 50.0,51.0 slot 0"], texts
  end

  def test_table_rule_under_the_header_and_lines_between_rows
    page = arrange("| a |\n|---|\n| b |\n| c |")
    boxes = Array.new(page.size) { |position| page.at(position) }.grep(Shipinel::Box).map(&:color)

    assert_equal [Shipinel::Theme::Surface::RULE, Shipinel::Theme::Surface::CODE_BACKGROUND,
                  Shipinel::Theme::Surface::CODE_BACKGROUND], boxes
  end

  def test_wide_table_cells_wrap_inside_their_column
    tops = commands("| curta | #{'palavra ' * 12}|", 300.0).grep(/palavra/).map { |line| line[/,(\S+)/, 1] }.uniq

    assert_operator tops.size, :>, 1
  end
end
