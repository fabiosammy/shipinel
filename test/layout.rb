# frozen_string_literal: true

# spin snapshot test: Layout compiled by Spinel must place every draw
# command where CRuby does. UI is replaced by a pure-Ruby stand-in, so the
# real TextMeasure runs in both: a font 0.5 * size wide per character.

# Stands in for the FFI module in lib/shipinel/ui.rb.
module Shipinel
  module UI
    #: (Integer slot, String text, Float size) -> Float
    def self.ui_text_width(_slot, text, size)
      text.size * size * 0.5
    end
  end
end

require_relative "../lib/shipinel/layout"
require_relative "../lib/shipinel/markdown/parser"
require_relative "../lib/shipinel/text_measure"

# Lays out a document 300 pixels wide and prints each draw command.
class LayoutSnapshot
  SOURCE = "# Semana 45\n\nFoco: **entregar** o `shipinel` hoje, sem falta.\n\n" \
           "- [ ] Reunião\n  - [x] Pauta\n* pão\n---\n```\nx\tcódigo\n```\nFim"

  #: () -> void
  def run
    blocks = Shipinel::Markdown::Parser.parse(SOURCE)
    page = Shipinel::Layout.new(Shipinel::TextMeasure.new, Shipinel::Styles.new(20.0), 300.0).arrange(blocks)
    puts "#{page.size} commands, height #{page.height.round(1)}"
    page.size.times { |position| puts describe(page.at(position)) }
  end

  #: (Shipinel::DrawCommand command) -> String
  def describe(command)
    "#{area(command.rect)} #{kind(command)}"
  end

  #: (Shipinel::DrawCommand command) -> String
  def kind(command)
    case command
    when Shipinel::TextRun then "text #{command.text.inspect} #{style(command.style)}"
    when Shipinel::Box then "box #{command.color.to_s(16)}"
    when Shipinel::Checkbox then "checkbox line #{command.click.line_index} #{command.click.checked?}"
    else "unknown"
    end
  end

  #: (Shipinel::TextStyle style) -> String
  def style(style)
    "slot #{style.font_slot} size #{style.size.round(1)} #{style.color.to_s(16)}"
  end

  #: (Shipinel::Rect rect) -> String
  def area(rect)
    "#{rect.left.round(1)},#{rect.top.round(1)} #{rect.width.round(1)}x#{rect.height.round(1)}"
  end
end

LayoutSnapshot.new.run
