# frozen_string_literal: true

# How the document is presented: its styles, where it is scrolled to, and
# the fonts (with their warnings). Each frame it applies the wheel and the
# scrollbar, reuses the document's layout unless something it depends on
# changed, and builds the overlay: progress header and scrollbar.

require_relative "content_cache"
require_relative "document_view"
require_relative "draw_list"
require_relative "font_set"
require_relative "frame"
require_relative "layout"
require_relative "progress_header"
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
    # @rbs @cache: ContentCache

    #: (Styles styles, FontSet fonts) -> void
    def initialize(styles, fonts)
      @styles = styles
      @fonts = fonts
      @scroll = Scroll.new
      @cache = ContentCache.new
    end

    # Glyphs are rendered at the largest size on the page (Styles), with
    # every character the document uses.
    #: (String text) -> void
    def load_fonts(text)
      @fonts.load(FontSet.codepoints_in(text), @styles.font_pixels)
      @cache.clear
    end

    # Loads the fonts again only when the text uses new characters.
    #: (String text) -> void
    def refresh_fonts(text)
      codepoints = FontSet.codepoints_in(text)
      return if @fonts.covers?(codepoints)

      @fonts.load(codepoints, @styles.font_pixels)
      @cache.clear
    end

    # The document scrolls in the window area below the header.
    #: (Screen screen, DocumentView document) -> Frame
    def update(screen, document)
      window = screen.area
      header = ProgressHeader.new(document.blocks.task_progress, @styles, window.width)
      area = window.below(header.height)
      content = content(area.width, document)
      framed(content, header, scroll(screen.mouse, content.height, area))
    end

    private

    #: (Float width, DocumentView document) -> DrawList
    def content(width, document)
      blocks = document.blocks
      notices = notices(document)
      key = LayoutKey.new(blocks, "#{width} #{notices.join("\n")}")
      return @cache.list if @cache.holds?(key)

      @cache.keep(key, Layout.new(@fonts, @styles, width).arrange(blocks, notices))
    end

    # Applies this frame's input; returns the bar where the page ended up.
    #: (MouseState mouse, Float page_height, Rect area) -> Scrollbar
    def scroll(mouse, page_height, area)
      bar = Scrollbar.new(page_height, area, @scroll.offset)
      bar.moved_to(@scroll.apply(mouse, bar))
    end

    #: (DrawList content, ProgressHeader header, Scrollbar bar) -> Frame
    def framed(content, header, bar)
      overlay = DrawList.new
      header.add_to(overlay)
      bar.add_to(overlay)
      Frame.new(content, overlay, Viewport.new(@scroll.offset, bar.area), @scroll.frame_rate)
    end

    #: (DocumentView document) -> Array[String]
    def notices(document)
      (@fonts.notices + document.notices).uniq
    end
  end
end
