# frozen_string_literal: true

# The fonts in the C shim's slots: loading them, asking which can draw a
# character, and measuring text. A thin FFI adapter, like Screen (.reek.yml);
# FontSet decides what to load and which font draws what.

require_relative "theme"

module Shipinel
  # See the file comment.
  class FontShim
    # Characters to load into every font from now on, beyond the base set.
    #: (Array[Integer] codepoints) -> void
    def use_codepoints(codepoints)
      UI.ui_set_extra_codepoints(codepoints, codepoints.size)
    end

    #: (Integer slot, String path, Integer pixel_size) -> void
    def load(slot, path, pixel_size)
      UI.ui_load_font(slot, path, pixel_size)
    end

    # False when the slot fell back to raylib's built-in font.
    #: (Integer slot) -> bool
    def loaded?(slot)
      UI.ui_font_loaded(slot)
    end

    # Whether the font in the slot can draw the character. (The shim
    # answers for all slots at once, bit n for slot n.)
    #: (Integer codepoint, Integer slot) -> bool
    def draws?(codepoint, slot)
      UI.ui_glyph_slots(codepoint).anybits?(1 << slot)
    end

    #: (String text, TextStyle style) -> Float
    def text_width(text, style)
      UI.ui_text_width(style.font_slot, text, style.size)
    end
  end
end
