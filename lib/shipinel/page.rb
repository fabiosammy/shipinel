# frozen_string_literal: true

# How the document is presented: its styles, where it is scrolled to, and
# the fonts (with their warnings). Each frame it reads the mouse; a frame
# that is due or shows a changed page applies the wheel and the scrollbar,
# reuses the document's layout unless something it depends on changed, and
# builds the overlay: progress header and scrollbar. Any other frame does
# nothing more.

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

    # Draws the next frame even if nothing changed.
    #: () -> void
    def redraw
      @cache.clear
    end

    # The frame to draw, or nil when nothing is to be drawn.
    #: (Screen screen, DocumentView document) -> Frame?
    def update(screen, document)
      mouse = screen.mouse
      key = LayoutKey.new(document.blocks, document.action_problem, screen.area)
      return unless wanted?(mouse, key)

      build(mouse, key, document)
    end

    private

    #: (MouseState mouse, LayoutKey key) -> bool
    def wanted?(mouse, key)
      @scroll.note(mouse)
      @scroll.due? || !@cache.holds?(key)
    end

    # The document scrolls in the window area below the header.
    #: (MouseState mouse, LayoutKey key, DocumentView document) -> Frame
    def build(mouse, key, document)
      window = key.area
      header = ProgressHeader.new(key.blocks.task_progress, @styles, window.width)
      area = window.below(header.height)
      content = content(key, area.width, document)
      Frame.of(content, header, scroll(mouse, content.height, area))
    end

    #: (LayoutKey key, Float width, DocumentView document) -> DrawList
    def content(key, width, document)
      return @cache.list if @cache.holds?(key)

      @cache.keep(key, Layout.new(@fonts, @styles, width).arrange(key.blocks, notices(document)))
    end

    # Applies this frame's input; returns the bar where the page ended up.
    #: (MouseState mouse, Float page_height, Rect area) -> Scrollbar
    def scroll(mouse, page_height, area)
      bar = Scrollbar.new(page_height, area, @scroll.offset)
      bar.moved_to(@scroll.apply(mouse, bar))
    end

    #: (DocumentView document) -> Array[String]
    def notices(document)
      (@fonts.notices + document.notices).uniq
    end
  end
end
