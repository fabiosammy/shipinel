# frozen_string_literal: true

# Every TextStyle the page uses, derived from the --font-size the user chose.

require_relative "theme"

module Shipinel
  # See the file comment.
  class Styles
    attr_reader :size #: Float

    #: (Float size) -> void
    def initialize(size)
      @size = size
    end

    #: () -> TextStyle
    def body
      TextStyle.new(Theme::FontSlot::BODY, @size, Theme::Ink::BODY)
    end

    # Notices about the file or the font, above the document.
    #: () -> TextStyle
    def problem
      TextStyle.new(Theme::FontSlot::BODY, @size, Theme::Accent::PROBLEM)
    end

    # Quoted text: italic and quieter than the text around it.
    #: () -> TextStyle
    def quote
      TextStyle.new(Theme::FontSlot::ITALIC, @size, Theme::Ink::MUTED)
    end

    # The header's "12 of 40 tasks done" and section line.
    #: () -> TextStyle
    def status
      TextStyle.new(Theme::FontSlot::BODY, @size * Theme::Scale::STATUS, Theme::Ink::BODY)
    end

    # The text of a checked task.
    #: () -> TextStyle
    def done
      TextStyle.new(Theme::FontSlot::BODY, @size, Theme::Ink::MUTED)
    end

    #: (Integer level) -> TextStyle
    def heading(level)
      boost = Theme::Scale::HEADING_BOOST * (Theme::Scale::HEADING_FALLOFF**(level - 1))
      TextStyle.new(Theme::FontSlot::BOLD, @size * (1.0 + boost), Theme::Ink::HEADING)
    end

    #: () -> TextStyle
    def code_block
      TextStyle.new(Theme::FontSlot::MONO, @size * Theme::Scale::CODE, Theme::Ink::CODE)
    end

    # Room on each side of a table cell's text.
    #: () -> Float
    def cell_padding
      @size * 0.4
    end

    #: () -> Float
    def checkbox_size
      @size * Theme::Scale::CHECKBOX
    end

    # Glyphs are rendered once, at the largest size on the page, and scaled
    # down for smaller text, which stays sharper than scaling up.
    #: () -> Integer
    def font_pixels
      heading(1).size.round
    end
  end
end
