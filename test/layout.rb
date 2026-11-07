# frozen_string_literal: true

# spin snapshot test: Layout compiled by Spinel must place every draw
# command where CRuby does, emoji in the symbol font and links clickable.
# UI is replaced by a pure-Ruby stand-in, so the real FontSet and FontShim
# run in both: a font 0.5 * size wide per character.

# Stands in for the FFI module in lib/shipinel/ui.rb: characters above
# U+FFFF (emoji) are only in the symbol font (slot 3, bit 8).
module Shipinel
  module UI
    LOADS = true

    #: (Integer slot, String text, Float size) -> Float
    def self.ui_text_width(_slot, text, size)
      text.size * size * 0.5
    end

    #: (Array[Integer] codepoints, Integer count) -> void
    def self.ui_set_extra_codepoints(codepoints, count)
      puts "extra codepoints #{codepoints.inspect} (#{count})"
    end

    #: (Integer slot, String path, Integer pixel_size) -> void
    def self.ui_load_font(slot, path, pixel_size)
      puts "load slot #{slot} #{path} #{pixel_size}"
    end

    #: (Integer slot) -> bool
    def self.ui_font_loaded(_slot)
      LOADS
    end

    #: (Integer codepoint) -> Integer
    def self.ui_glyph_slots(codepoint)
      codepoint > 0xFFFF ? 8 : 1
    end
  end
end

require_relative "../lib/shipinel/layout"
require_relative "../lib/shipinel/markdown/parser"
require_relative "../lib/shipinel/font_set"
require_relative "../lib/shipinel/font_shim"

# Lays out a document 300 pixels wide and prints each draw command.
class LayoutSnapshot
  SOURCE = "# Semana 45\n\nFoco: **entregar** o `shipinel` hoje, sem falta.\n\n" \
           "- [ ] 🤖 Reunião → [DOS-558](https://linear.app/x)\n  - [x] Pauta\n* pão\n---\n```\nx\tcódigo\n```\nFim"
  PATHS = Shipinel::FontPaths.new("/s.ttf", "/b.ttf", "/m.ttf", "/e.ttf")

  #: () -> Shipinel::FontSet
  def fonts
    fonts = Shipinel::FontSet.new(Shipinel::FontShim.new, PATHS)
    fonts.load(Shipinel::FontSet.codepoints_in(SOURCE), 32)
    fonts
  end

  #: () -> void
  def run
    blocks = Shipinel::Markdown::Parser.parse(SOURCE)
    layout = Shipinel::Layout.new(fonts, Shipinel::Styles.new(20.0), 300.0)
    page = layout.arrange(blocks, ["Cannot save semana.md: Permission denied"])
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
    when Shipinel::LinkArea then "link #{command.url}"
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
