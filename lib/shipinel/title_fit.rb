# frozen_string_literal: true

# A title cut with "…" to fit a width, measured in the style it is drawn in:
# the header's section line.

require_relative "font_set"
require_relative "theme"

module Shipinel
  # See the file comment.
  class TitleFit
    ELLIPSIS = "…"

    # @rbs @fonts: FontSet
    # @rbs @style: TextStyle
    # @rbs @room: Float
    # How many characters of the title fit kept so far.
    # @rbs @kept: Integer

    #: (FontSet fonts, TextStyle style, Float room) -> void
    def initialize(fonts, style, room)
      @fonts = fonts
      @style = style
      @room = room
      @kept = 0
    end

    # The first `kept` characters of `title`, and "…".
    #: (String title, Integer kept) -> String
    def self.cut(title, kept)
      "#{title[0, kept].to_s.rstrip}#{ELLIPSIS}"
    end

    # Characters come off the end until the rest and "…" fit.
    #: (String title) -> String
    def fit(title)
      @kept = title.size
      shown = title
      shown = shorter(title) until @kept <= 1 || fits?(shown)
      shown
    end

    private

    #: (String title) -> String
    def shorter(title)
      @kept -= 1
      TitleFit.cut(title, @kept)
    end

    #: (String text) -> bool
    def fits?(text)
      @fonts.text_width(text, @style) <= @room
    end
  end
end
