# frozen_string_literal: true

require_relative "../../../lib/shipinel/font_set"

# A FontShim without the C shim: every font is 0.5 * size wide per
# character, characters above U+FFFF (emoji) are only in the symbol font,
# and fonts load unless their path is in `failing`.
class FakeShim
  attr_reader :calls

  def initialize(failing: [])
    @failing = failing
    @calls = []
    @paths = {}
  end

  def use_codepoints(codepoints) = @calls << [:use, codepoints]

  def load(slot, path, size)
    @calls << [:load, slot, path, size]
    @paths[slot] = path
  end

  def loaded?(slot) = !@failing.include?(@paths[slot])
  def draws?(codepoint, slot) = (codepoint > 0xFFFF) == (slot == Shipinel::Theme::FontSlot::SYMBOL)

  # Counted, to show when the page is laid out again.
  def text_width(text, style)
    @measured = measured + 1
    text.size * style.size * 0.5
  end

  def measured = @measured || 0
end

PATHS = Shipinel::FontPaths.new(Shipinel::TextFaces.new("/s.ttf", "/b.ttf", "/i.ttf"), "/m.ttf", "/e.ttf")

# A FontSet over a FakeShim, loaded with the characters of `text`.
def fake_font_set(text = "", failing: [])
  fonts = Shipinel::FontSet.new(FakeShim.new(failing: failing), PATHS)
  fonts.load(Shipinel::FontSet.codepoints_in(text), 32)
  fonts
end
