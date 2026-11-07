# frozen_string_literal: true

# The one dark theme, in one place: colors (0xRRGGBBAA, the form the C shim
# takes), spacing and type scale. Nothing else in the app writes a color
# number or a spacing ratio.

module Shipinel
  module Theme
    # What text and marks are drawn on.
    module Surface
      BACKGROUND = 0x1D1F24FF
      CODE_BACKGROUND = 0x2A2D35FF
      RULE = 0x3A3E48FF
      SCROLL_TRACK = 0x25282EFF
      SCROLL_THUMB = 0x4B5160FF
    end

    # Text colors.
    module Ink
      BODY = 0xDCDFE4FF
      HEADING = 0xF2F4F8FF
      # Done tasks fade back.
      MUTED = 0x7E8490FF
      CODE = 0xE5C07BFF
    end

    # Colors that ask for attention.
    module Accent
      LINK = 0x7AA2F7FF
      PROBLEM = 0xE06C75FF
    end

    # The progress header pinned to the top of the window.
    module Progress
      BAND = 0x24272EFF
      TRACK = 0x3A3E48FF
      FILL = 0x7AA2F7FF
      # Every task checked.
      COMPLETE = 0x98C379FF
    end

    # Task checkboxes.
    module Checkbox
      BORDER = 0x6B7280FF
      HOVER = 0x9FB4FFFF
      CHECK = 0x7AA2F7FF
    end

    # Font slots in the C shim: which loaded font a TextStyle uses.
    module FontSlot
      BODY = 0
      MONO = 1
      BOLD = 2
      # Emoji and other symbols the text fonts lack.
      SYMBOL = 3
      ITALIC = 4
    end

    # Spacing, in multiples of the body font size unless said otherwise.
    module Spacing
      # Pixels between the window edge and the page.
      MARGIN = 16.0
      # Line height as a multiple of the text size.
      LINE = 1.35
      # Indentation added per list nesting depth.
      INDENT = 1.4
      # Room for the bullet or checkbox before a list item's text.
      MARKER = 1.5
      # After paragraphs and around headings and rules.
      BLOCK_GAP = 0.6
    end

    # Text sizes relative to the body font size.
    module Scale
      # A level 1 heading is this much bigger than body text...
      HEADING_BOOST = 0.6
      # ...and each level below keeps this share of the boost above it:
      # 1.6, 1.36, 1.22, 1.13, 1.08, 1.05.
      HEADING_FALLOFF = 0.6
      CODE = 0.9
      CHECKBOX = 0.85
      STATUS = 0.85
    end
  end

  # How a run of text is drawn: which font slot, how big, what color.
  class TextStyle
    attr_reader :font_slot #: Integer
    attr_reader :size #: Float
    attr_reader :color #: Integer

    #: (Integer font_slot, Float size, Integer color) -> void
    def initialize(font_slot, size, color)
      @font_slot = font_slot
      @size = size
      @color = color
    end

    #: () -> Float
    def line_height
      @size * Theme::Spacing::LINE
    end

    #: (Integer font_slot) -> TextStyle
    def with_font(font_slot)
      TextStyle.new(font_slot, @size, @color)
    end

    #: (Integer color) -> TextStyle
    def with_color(color)
      TextStyle.new(@font_slot, @size, color)
    end
  end
end
