# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/layout"
require_relative "../../lib/shipinel/markdown/parser"

class QuoteTest < Minitest::Test
  STYLES = Shipinel::Styles.new(20.0)

  def blocks(source)
    parsed = Shipinel::Markdown::Parser.parse(source)
    Array.new(parsed.size) { |position| parsed.at(position) }
  end

  def summary(source)
    blocks(source).map { |block| "#{block.line_index}: #{block.class.name.split('::').last} #{block.text}" }
  end

  def test_quoted_lines_join_and_a_bare_marker_starts_a_new_quote
    assert_equal ["0: Paragraph antes", "1: Quote Primeira continua", "4: Quote Segundo", "5: Paragraph depois"],
                 summary("antes\n> Primeira\n> continua\n>\n> Segundo\ndepois")
  end

  def test_markdown_inside_a_quote_is_shown_as_written
    assert_equal ["0: Quote - item"], summary("> - item")
  end

  def quoted_page
    Shipinel::Layout.new(fake_font_set, STYLES, 400.0).arrange(Shipinel::Markdown::Parser.parse("> citado"), [])
  end

  def test_quote_text_is_indented_italic_and_muted
    text = quoted_page.at(0)

    assert_equal [36.0, Shipinel::Theme::FontSlot::ITALIC, Shipinel::Theme::Ink::MUTED],
                 [text.rect.left, text.style.font_slot, text.style.color]
  end

  def test_quote_has_a_bar_as_tall_as_its_text
    rect = quoted_page.at(1).rect

    assert_equal [16.0, 16.0, 3.0, 27.0], [rect.left, rect.top, rect.width, rect.height]
  end
end
