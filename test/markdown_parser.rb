# frozen_string_literal: true

# spin snapshot test: the parser and inline spans compiled by Spinel must
# print what CRuby prints for the same document.

require_relative "../lib/shipinel/markdown/parser"
require_relative "../lib/shipinel/markdown/inline"

# Prints one line per block, then the spans of every inline-styled text.
class ParserSnapshot
  SOURCE = "# Semana 45 ##\r\n\r\nFoco: **entregar** o `shipinel`.\r\nSem reuniões.\r\n\r\n" \
           "- [ ] Reunião\r\n  - [x] Pauta\r\n    * [X] Ana\r\n+ [ ] Ação\r\n---\r\n" \
           "* pão\r\n\t* queijo\r\n- [ ]\r\n```\r\n- [ ] não é tarefa\r\n````\r\n~~~\r\nx\r\nFim"

  #: () -> void
  def run
    blocks = Shipinel::Markdown::Parser.parse(SOURCE)
    position = 0
    while position < blocks.size
      puts describe(blocks.at(position))
      position += 1
    end
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
    when Shipinel::Markdown::Bullet then "bullet #{block.depth} #{spans(block.text)}"
    when Shipinel::Markdown::Paragraph then "paragraph #{spans(block.text)}"
    when Shipinel::Markdown::CodeLine then "code [#{block.text}]"
    else "rule"
    end
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
