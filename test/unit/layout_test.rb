# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/layout"
require_relative "../../lib/shipinel/markdown/parser"

# With size 20: line height 27, margin 16, marker 30, indent 28 per depth,
# block gap 12; the fake font is 0.5 * size wide per character.
class LayoutTest < Minitest::Test
  class FakeMeasurer
    def text_width(text, style) = text.size * style.size * 0.5
  end

  STYLES = Shipinel::Styles.new(20.0)

  def arrange(source, width = 400.0)
    Shipinel::Layout.new(FakeMeasurer.new, STYLES, width).arrange(Shipinel::Markdown::Parser.parse(source))
  end

  def commands(source, width = 400.0)
    page = arrange(source, width)
    Array.new(page.size) { |position| describe(page.at(position)) }
  end

  def describe(command)
    case command
    when Shipinel::TextRun then "text #{command.text.inspect} at #{xy(command.rect)} slot #{command.style.font_slot}"
    when Shipinel::Box then "box #{rect(command.rect)}"
    else "check #{rect(command.rect)} line #{command.click.line_index} #{command.click.checked?}"
    end
  end

  def xy(point) = "#{point.left.round(1)},#{point.top.round(1)}"
  def rect(rect) = "#{xy(rect)} #{rect.width.round(1)}x#{rect.height.round(1)}"

  def test_empty_document_is_just_margins
    assert_equal [0, 32.0], [arrange("").size, arrange("").height]
  end

  def test_paragraph_words_and_page_height
    assert_equal ["text \"uma \" at 16.0,16.0 slot 0", "text \"frase\" at 56.0,16.0 slot 0"], commands("uma frase")
    assert_in_delta 71.0, arrange("uma frase").height
  end

  def test_words_wrap_at_the_right_margin
    tops = commands("aaaa bbbb cccc", 100.0).map { |command| command[/,(\S+)/, 1] }

    assert_equal %w[16.0 43.0 70.0], tops
  end

  def test_space_left_at_a_line_start_is_dropped
    assert_equal ["text \"aaaaaaa\" at 16.0,16.0 slot 2", "text \"bbbb\" at 16.0,43.0 slot 0"],
                 commands("**aaaaaaa** bbbb", 100.0)
  end

  def test_heading_uses_the_bold_slot_and_has_no_gap_at_the_top
    assert_equal ["text \"Semana\" at 16.0,16.0 slot 2"], commands("# Semana")
  end

  def test_heading_after_text_gets_a_gap
    assert_equal "text \"Dia\" at 16.0,67.0 slot 2", commands("x\n## Dia").last
  end

  def test_task_checkbox_carries_its_line_and_state
    assert_equal ["check 16.0,21.0 17.0x17.0 line 0 true", "text \"feito\" at 46.0,16.0 slot 0"],
                 commands("- [x] feito")
  end

  def test_checked_task_text_is_muted
    page = arrange("- [x] feito\n- [ ] não")

    assert_equal [Shipinel::Theme::Ink::MUTED, Shipinel::Theme::Ink::BODY],
                 [page.at(1).style.color, page.at(3).style.color]
  end

  def test_nested_items_indent_by_depth
    assert_equal "check 44.0,48.0 17.0x17.0 line 1 false", commands("- [ ] a\n  - [ ] b")[2]
  end

  def test_bullet_marker_and_text
    assert_equal ["text \"•\" at 24.0,16.0 slot 0", "text \"pão\" at 46.0,16.0 slot 0"], commands("* pão")
  end

  def test_code_line_on_a_background_without_wrapping
    expected = ["box 16.0,16.0 68.0x24.3", "text \"a    b c d e f g h\" at 34.0,16.0 slot 1"]

    assert_equal expected, commands("```\na\tb c d e f g h\n```", 100.0)
  end

  def test_code_run_gets_room_around_it
    tops = commands("x\n```\ny\n```\nz").map { |command| command[/,(\S+)/, 1] }

    assert_equal %w[16.0 61.0 61.0 91.3], tops
  end

  def test_rule_is_a_thin_box_between_gaps
    assert_equal ["box 16.0,22.0 368.0x1.0"], commands("---")
  end

  def test_inline_code_gets_its_background
    assert_equal ["box 16.0,16.0 18.0x27.0", "text \"ok\" at 16.0,17.4 slot 1"], commands("`ok`")
  end
end
