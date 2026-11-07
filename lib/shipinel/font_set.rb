# frozen_string_literal: true

# The four fonts the window draws with, loaded with the characters the
# document uses: the base set (Latin) is always there, and arrows, symbols
# and emoji are added as they appear. A character the body font cannot draw
# but the symbol font can (emoji, mostly) is drawn in the symbol font.

require_relative "font_locator"
require_relative "font_shim"
require_relative "line_wrap"
require_relative "theme"

module Shipinel
  # See the file comment.
  class FontSet
    # @rbs @shim: FontShim
    # @rbs @paths: FontPaths
    # @rbs @loaded: Array[Integer]
    # @rbs @symbols: Array[Integer]

    # The base set ends here (Latin Extended-A); the C shim always loads it.
    BASE_END = 0x17F

    # The characters of `text` beyond the base set, each once, sorted.
    # LineWrap drops the invisible joiners, so they are not loaded.
    #: (String text) -> Array[Integer]
    def self.codepoints_in(text)
      text.delete(LineWrap::INVISIBLE).codepoints.uniq.select { |codepoint| codepoint > BASE_END }.sort
    end

    #: (FontShim shim, FontPaths paths) -> void
    def initialize(shim, paths)
      @shim = shim
      @paths = paths
      @loaded = [0]
      @symbols = [0]
    end

    # Loads every slot with these extra characters.
    #: (Array[Integer] codepoints, Integer pixel_size) -> void
    def load(codepoints, pixel_size)
      @shim.use_codepoints(codepoints)
      load_slots(pixel_size)
      remember(codepoints)
    end

    # Loads again only when the document now uses characters not loaded.
    #: (Array[Integer] codepoints, Integer pixel_size) -> void
    def refresh(codepoints, pixel_size)
      load(codepoints, pixel_size) unless (codepoints - @loaded).empty?
      nil
    end

    # Whether the character is drawn in the symbol font.
    #: (Integer codepoint) -> bool
    def symbol?(codepoint)
      @symbols.include?(codepoint)
    end

    # The text cut where it switches between the text and symbol fonts:
    # "feito 🤖 ok" gives "feito ", "🤖", " ok".
    #: (String text) -> Array[String]
    def pieces(text)
      PieceCutter.new(self).cut(text)
    end

    #: (String text, TextStyle style) -> Float
    def text_width(text, style)
      @shim.text_width(text, style)
    end

    # One for each font that fell back to raylib's built-in one.
    #: () -> Array[String]
    def notices
      [notice(Theme::FontSlot::BODY, @paths.body), notice(Theme::FontSlot::BOLD, @paths.bold),
       notice(Theme::FontSlot::MONO, @paths.mono), notice(Theme::FontSlot::SYMBOL, @paths.symbol)].reject(&:empty?).uniq
    end

    private

    #: (Array[Integer] codepoints) -> void
    def remember(codepoints)
      @loaded = codepoints
      @symbols = codepoints.select { |codepoint| symbol_only?(codepoint) }
      nil
    end

    #: (Integer pixel_size) -> void
    def load_slots(pixel_size)
      @shim.load(Theme::FontSlot::BODY, @paths.body, pixel_size)
      @shim.load(Theme::FontSlot::BOLD, @paths.bold, pixel_size)
      @shim.load(Theme::FontSlot::MONO, @paths.mono, pixel_size)
      @shim.load(Theme::FontSlot::SYMBOL, @paths.symbol, pixel_size)
    end

    #: (Integer codepoint) -> bool
    def symbol_only?(codepoint)
      !@shim.draws?(codepoint, Theme::FontSlot::BODY) && @shim.draws?(codepoint, Theme::FontSlot::SYMBOL)
    end

    #: (Integer slot, String path) -> String
    def notice(slot, path)
      return "" if @shim.loaded?(slot)

      "Could not load the font \"#{path}\" (raylib reads .ttf and .otf files): " \
        "some characters will not show in it. Try --font or --emoji-font."
    end
  end

  # Collects text into pieces, starting a new one where the font changes.
  class PieceCutter
    # @rbs @fonts: FontSet
    # @rbs @pieces: Array[String]

    #: (FontSet fonts) -> void
    def initialize(fonts)
      @fonts = fonts
      @pieces = [""]
    end

    #: (String text) -> Array[String]
    def cut(text)
      text.each_char { |char| add(char) }
      @pieces.reject(&:empty?)
    end

    private

    #: (String char) -> void
    def add(char)
      last = @pieces.last.to_s
      if last.empty? || @fonts.symbol?(last.ord) == @fonts.symbol?(char.ord)
        @pieces[-1] = last + char
      else
        @pieces << char
      end
      nil
    end
  end
end
