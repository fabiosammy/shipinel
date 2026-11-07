# frozen_string_literal: true

# How the document is presented: its styles, where it is scrolled to, and
# the fonts (with their warnings). Each frame it lays the document out for
# the window's current size, applies the wheel and the scrollbar, and adds
# the scrollbar to the page.

require_relative "document_view"
require_relative "draw_list"
require_relative "font_set"
require_relative "layout"
require_relative "screen"
require_relative "scroll"
require_relative "scrollbar"
require_relative "styles"

module Shipinel
  # See the file comment.
  class Page
    # @rbs @styles: Styles
    # @rbs @fonts: FontSet
    # @rbs @scroll: Scroll

    #: (Styles styles, FontSet fonts) -> void
    def initialize(styles, fonts)
      @styles = styles
      @fonts = fonts
      @scroll = Scroll.new
    end

    #: () -> Float
    def offset
      @scroll.offset
    end

    # Glyphs are rendered at the largest size on the page (Styles), with
    # every character the document uses.
    #: (String text) -> void
    def load_fonts(text)
      @fonts.load(FontSet.codepoints_in(text), @styles.font_pixels)
    end

    # Loads the fonts again only when the text uses new characters.
    #: (String text) -> void
    def refresh_fonts(text)
      @fonts.refresh(FontSet.codepoints_in(text), @styles.font_pixels)
    end

    #: (Screen screen, DocumentView document) -> DrawList
    def lay_out(screen, document)
      area = screen.area
      page = Layout.new(@fonts, @styles, area.width).arrange(document.blocks, notices(document))
      scroll(screen.mouse, page, area)
      page
    end

    private

    # The bar is drawn where the page ended up after this frame's input.
    #: (MouseState mouse, DrawList page, Rect area) -> void
    def scroll(mouse, page, area)
      bar = Scrollbar.new(page.height, area, @scroll.offset)
      bar.moved_to(@scroll.apply(mouse, bar)).add_to(page)
    end

    #: (DocumentView document) -> Array[String]
    def notices(document)
      (@fonts.notices + document.notices).uniq
    end
  end
end
