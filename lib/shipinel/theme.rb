# frozen_string_literal: true

# The one dark theme, in one place. Colors are 0xRRGGBBAA, the form the C
# shim takes; nothing else in the app writes a color number.

module Shipinel
  module Theme
    # What text and marks are drawn on.
    module Surface
      BACKGROUND = 0x1D1F24FF
      CODE_BACKGROUND = 0x2A2D35FF
      RULE = 0x3A3E48FF
    end

    # Text colors.
    module Ink
      BODY = 0xDCDFE4FF
      HEADING = 0xF2F4F8FF
      MUTED = 0x8B919CFF
      CODE = 0xE5C07BFF
      PROBLEM = 0xE06C75FF
    end

    # Font slots in the C shim: which loaded font a TextStyle uses.
    module FontSlot
      BODY = 0
      MONO = 1
    end
  end

  # A position in the window, in pixels from its top-left corner.
  class Point
    attr_reader :left #: Float
    attr_reader :top #: Float

    #: (Float left, Float top) -> void
    def initialize(left, top)
      @left = left
      @top = top
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
  end
end
