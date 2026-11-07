# frozen_string_literal: true

# How wide a piece of text is in a given style, from the font loaded in the
# C shim. All Layout needs of the window, so Layout depends on this rather
# than on Screen (and the layout snapshot test can stand in for one call).

require_relative "theme"

module Shipinel
  # See the file comment. An FFI adapter like Screen (.reek.yml).
  class TextMeasure
    #: (String text, TextStyle style) -> Float
    def text_width(text, style)
      UI.ui_text_width(style.font_slot, text, style.size)
    end
  end
end
