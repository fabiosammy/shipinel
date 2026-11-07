# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../../lib/shipinel/markdown/inline"

# Single `*` and `_` markers: italic only when they hug the text, and `_`
# only at the edges of a word, so snake_case names stay as written.
class EmphasisTest < Minitest::Test
  def spans(text)
    list = Shipinel::Markdown::Inline.parse(text)
    Array.new(list.size) { |position| "#{list.at(position).style}:#{list.at(position).text}" }
  end

  def test_markers_must_hug_the_text
    assert_equal ["plain:2 * 3 * 4 e * solto*"], spans("2 * 3 * 4 e * solto*")
  end

  def test_underscores_inside_words_stay
    assert_equal ["plain:workspace_id, snake_case_name, _a_b"], spans("workspace_id, snake_case_name, _a_b")
  end

  def test_underscore_italic_at_word_edges
    assert_equal ["plain:um ", "italic:itálico", "plain: aqui"], spans("um _itálico_ aqui")
  end

  def test_star_italic_inside_a_word
    assert_equal ["plain:in", "italic:crí", "plain:vel"], spans("in*crí*vel")
  end

  def test_unclosed_markers_stay
    assert_equal ["plain:*a e _b"], spans("*a e _b")
  end

  def test_bold_is_not_italic
    assert_equal ["bold:negrito"], spans("**negrito**")
  end
end
