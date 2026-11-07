# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../../lib/shipinel/markdown/inline"

class InlineTest < Minitest::Test
  # "style:text" for every span, in order.
  def spans(text)
    list = Shipinel::Markdown::Inline.parse(text)
    Array.new(list.size) { |position| "#{list.at(position).style}:#{list.at(position).text}" }
  end

  def test_empty_text_has_no_spans
    assert_empty spans("")
  end

  def test_plain_text_is_one_span
    assert_equal ["plain:Reunião às 10h"], spans("Reunião às 10h")
  end

  def test_bold_and_code_between_plain
    assert_equal ["plain:Foco: ", "bold:ação", "plain: no ", "code:shipinel", "plain:."],
                 spans("Foco: **ação** no `shipinel`.")
  end

  def test_spans_at_both_ends
    assert_equal ["bold:a", "plain: ", "code:b"], spans("**a** `b`")
  end

  def test_unclosed_markers_stay_literal
    assert_equal ["plain:2 ** 3 e `x"], spans("2 ** 3 e `x")
  end

  def test_empty_markers_stay_literal
    assert_equal ["plain:**** e ``"], spans("**** e ``")
  end

  def test_code_wins_over_bold_inside_it
    assert_equal ["code:**não negrito**"], spans("`**não negrito**`")
  end

  def test_single_star_is_text
    assert_equal ["plain:*itálico*"], spans("*itálico*")
  end
end
