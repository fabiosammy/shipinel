# frozen_string_literal: true

# Turns the document into a laid-out page with the fonts it needs, and
# keeps the last page until something it depends on changes (ContentCache):
# the blocks, the click's problem, the window size, or the fonts.

require_relative "content_cache"
require_relative "document_view"
require_relative "font_set"
require_relative "layout"
require_relative "styles"

module Shipinel
  # See the file comment.
  class Typesetter
    attr_reader :fonts #: FontSet

    # @rbs @cache: ContentCache

    #: (FontSet fonts) -> void
    def initialize(fonts)
      @fonts = fonts
      @cache = ContentCache.new
    end

    # Every character the text uses, rendered at `pixels` (Styles).
    #: (String text, Integer pixels) -> void
    def load(text, pixels)
      @fonts.load(FontSet.codepoints_in(text), pixels)
      @cache.clear
    end

    # Loads the fonts again only when the text uses new characters.
    #: (String text, Integer pixels) -> void
    def refresh(text, pixels)
      codepoints = FontSet.codepoints_in(text)
      return if @fonts.covers?(codepoints)

      @fonts.load(codepoints, pixels)
      @cache.clear
    end

    # The same characters at another size (a zoom).
    #: (Integer pixels) -> void
    def resize(pixels)
      @fonts.reload(pixels)
      @cache.clear
    end

    # The next page is laid out and drawn even if nothing changed.
    #: () -> void
    def forget
      @cache.clear
    end

    #: (LayoutKey key) -> bool
    def holds?(key)
      @cache.holds?(key)
    end

    # The page laid out last.
    #: () -> DrawList
    def last
      @cache.list
    end

    # Notices (the file's and the fonts') go above the document.
    #: (LayoutKey key, Styles styles, DocumentView document) -> DrawList
    def page_for(key, styles, document)
      return @cache.list if @cache.holds?(key)

      notices = (@fonts.notices + document.notices).uniq
      @cache.keep(key, Layout.new(@fonts, styles, key.area.width).arrange(key.blocks, notices))
    end
  end
end
