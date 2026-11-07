# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../../lib/shipinel/markdown/parser"

class ParserTest < Minitest::Test
  FIXTURE = File.expand_path("../../fixtures/semana.md", __dir__)

  # One readable line per block, so a test compares whole documents at once.
  def summary(source)
    blocks = Shipinel::Markdown::Parser.parse(source)
    Array.new(blocks.size) { |position| describe(blocks.at(position)) }
  end

  def describe(block)
    "#{block.line_index}: #{kind(block)}"
  end

  def kind(block)
    case block
    when Shipinel::Markdown::Heading then "h#{block.level} #{block.text}"
    when Shipinel::Markdown::ListItem then list_item(block)
    when Shipinel::Markdown::Paragraph then "p #{block.text}"
    when Shipinel::Markdown::CodeLine then "code #{block.text}"
    else "rule"
    end
  end

  def list_item(item)
    return "bullet d#{item.depth} #{item.text}" unless item.is_a?(Shipinel::Markdown::Task)

    "task d#{item.depth} #{item.checked? ? '[x]' : '[ ]'} #{item.text}"
  end

  def test_empty_file_has_no_blocks
    assert_empty summary("")
  end

  def test_blank_lines_only
    assert_empty summary("\n  \n\t\n")
  end

  def test_headings_by_level
    assert_equal ["0: h1 Semana", "1: h2 Segunda", "2: h3 Manhã", "3: h2 "],
                 summary("# Semana\n## Segunda\n### Manhã ##\n##")
  end

  def test_hash_without_space_is_text
    assert_equal ["0: p #tag"], summary("#tag")
  end

  def test_task_states_and_bullets
    expected = ["0: task d0 [ ] a", "1: task d0 [x] b", "2: task d0 [x] c", "3: task d0 [ ] "]

    assert_equal expected, summary("- [ ] a\n* [x] b\n+ [X] c\n- [ ]")
  end

  def test_nesting_by_indentation_of_two_or_four
    two = summary("- [ ] a\n  - [ ] b\n    - [ ] c\n  - [ ] d")
    four = summary("- [ ] a\n    - [ ] b\n        - [ ] c\n    - [ ] d")

    assert_equal ["0: task d0 [ ] a", "1: task d1 [ ] b", "2: task d2 [ ] c", "3: task d1 [ ] d"], two
    assert_equal two, four
  end

  def test_tab_indents_like_four_spaces
    assert_equal ["0: bullet d0 a", "1: bullet d1 b"], summary("- a\n\t- b")
  end

  def test_mixed_bullets_and_tasks_nest_together
    assert_equal ["0: bullet d0 compras", "1: task d1 [ ] pão", "2: bullet d1 leite"],
                 summary("* compras\n  - [ ] pão\n  + leite")
  end

  def test_rules
    assert_equal ["0: rule", "1: rule", "2: rule", "3: bullet d0 -"], summary("---\n* * *\n___\n- -")
  end

  def test_paragraph_joins_consecutive_lines
    assert_equal ["0: p uma frase longa", "3: p outra"], summary("uma frase\n  longa\n\noutra")
  end

  def test_paragraph_after_list_ends_the_list
    assert_equal ["0: bullet d0 a", "1: p texto", "2: bullet d0 b"], summary("  - a\ntexto\n    - b")
  end

  def test_fenced_lines_are_never_tasks
    expected = ["1: code - [ ] não é tarefa", "2: code ", "4: task d0 [ ] é tarefa"]

    assert_equal expected, summary("```ruby\n- [ ] não é tarefa\n\n```\n- [ ] é tarefa")
  end

  def test_fence_closes_only_with_same_marker_at_least_as_long
    expected = ["1: code ~~~", "2: code ``", "4: p fim"]

    assert_equal expected, summary("```\n~~~\n``\n````\nfim")
  end

  def test_unclosed_fence_runs_to_end_of_file
    assert_equal ["1: code # não é título"], summary("~~~\n# não é título")
  end

  def test_crlf_lines_keep_their_indexes
    assert_equal ["0: h1 Título", "2: task d0 [x] Reunião"], summary("# Título\r\n\r\n- [x] Reunião\r\n")
  end

  def test_portuguese_fixture
    lines = summary(File.read(FIXTURE))

    assert_equal "7: task d0 [ ] Reunião de planejamento", lines[3]
    assert_equal "10: task d2 [ ] Confirmar com a Ana", lines[6]
    assert_equal "22: code - [ ] isto não é uma tarefa", lines[-2]
  end
end
