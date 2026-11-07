# frozen_string_literal: true

# spin snapshot test: the parser and inline spans compiled by Spinel must
# print what CRuby prints for the same document.

require_relative "../lib/shipinel/markdown/parser"
require_relative "../lib/shipinel/markdown/inline"

# Prints one line per block, then the spans of every inline-styled text.
class ParserSnapshot
  SOURCE = "# Semana 45 ##\r\n\r\nFoco: **entregar** o `shipinel`.\r\nSem reuniões.\r\n\r\n" \
           "> _Citação_ e *mais*\r\n> junto\r\n>\r\n> outra\r\n" \
           "- [ ] Reunião\r\n  - [x] Pauta\r\n    * [X] Ana\r\n+ [ ] Ação\r\n1. **Drata**\r\n2) [x] Twingate\r\n" \
           "| Goal | State |\r\n|---|:-:|\r\n| Drata | 12 |\r\n| Twingate |\r\n---\r\n" \
           "* pão\r\n\t* queijo\r\n- [ ]\r\n```\r\n- [ ] não é tarefa\r\n````\r\n~~~\r\nx\r\nFim"

  #: () -> void
  def run
    blocks = Shipinel::Markdown::Parser.parse(SOURCE)
    position = 0
    while position < blocks.size
      puts describe(blocks.at(position))
      position += 1
    end
    puts blocks.task_progress.label
    nil
  end

  #: (Shipinel::Markdown::Block block) -> String
  def describe(block)
    "#{block.line_index} #{kind(block)}"
  end

  #: (Shipinel::Markdown::Block block) -> String
  def kind(block)
    case block
    when Shipinel::Markdown::Heading then "heading #{block.level} #{spans(block.text)}"
    when Shipinel::Markdown::Task then "task #{block.depth} #{block.checked?} #{spans(block.text)}"
    when Shipinel::Markdown::Bullet then "bullet #{block.depth} #{block.marker} #{spans(block.text)}"
    else other(block)
    end
  end

  #: (Shipinel::Markdown::Block block) -> String
  def other(block)
    case block
    when Shipinel::Markdown::Paragraph then "paragraph #{spans(block.text)}"
    when Shipinel::Markdown::CodeLine then "code [#{block.text}]"
    when Shipinel::Markdown::Quote then "quote #{spans(block.text)}"
    else table_or_rule(block)
    end
  end

  #: (Shipinel::Markdown::Block block) -> String
  def table_or_rule(block)
    return "rule" unless block.is_a?(Shipinel::Markdown::Table)

    "table #{block.columns}x#{block.rows} header #{block.header_rows} " \
      "#{block.text.split(Shipinel::Markdown::Table::SEPARATOR, -1).join('|')}"
  end

  #: (String text) -> String
  def spans(text)
    list = Shipinel::Markdown::Inline.parse(text)
    out = ""
    position = 0
    while position < list.size
      span = list.at(position)
      out = "#{out}<#{span.style}:#{span.text}>"
      position += 1
    end
    out
  end
end

ParserSnapshot.new.run
