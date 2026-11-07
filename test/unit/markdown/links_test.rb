# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../../lib/shipinel/markdown/links"

class LinksTest < Minitest::Test
  def found(text)
    link = Shipinel::Markdown::Links.at(text)
    link && [link.text, link.url, link.length]
  end

  def test_markdown_link
    assert_equal ["DOS-558", "https://linear.app/x", 31], found("[DOS-558](https://linear.app/x) resto")
  end

  def test_relative_markdown_link
    assert_equal ["semana", "week-2026-10-26-runbook.md", 36], found("[semana](week-2026-10-26-runbook.md)")
  end

  def test_angle_autolink
    assert_equal ["https://a.test/b", "https://a.test/b", 18], found("<https://a.test/b> e")
  end

  def test_bare_url_leaves_out_sentence_punctuation
    assert_equal ["https://c.test/d?x=1", "https://c.test/d?x=1", 20], found("https://c.test/d?x=1).")
  end

  def test_not_a_link
    assert_nil found("[só colchetes] e (parênteses)")
    assert_nil found("http e mais nada")
  end
end
