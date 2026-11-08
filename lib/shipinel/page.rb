# frozen_string_literal: true

# How the document is presented: its View (text size, header), where it is
# scrolled to, and the fonts (with their warnings). Each frame it reads the
# input and applies the zoom and header keys; a frame
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
require_relative "view"

module Shipinel
  # See the file comment.
  class Page
    # @rbs @view: View
    # @rbs @fonts: FontSet
    # @rbs @scroll: Scroll
    # @rbs @cache: ContentCache

    #: (View view, FontSet fonts) -> void
    def initialize(view, fonts)
      @view = view
      @fonts = fonts
      @scroll = Scroll.new
      @cache = ContentCache.new
    end

    # Glyphs are rendered at the largest size on the page (Styles), with
    # every character the document uses.
    #: (String text) -> void
    def load_fonts(text)
      @fonts.load(FontSet.codepoints_in(text), font_pixels)
      @cache.clear
    end

    # Loads the fonts again only when the text uses new characters.
    #: (String text) -> void
    def refresh_fonts(text)
      codepoints = FontSet.codepoints_in(text)
      return if @fonts.covers?(codepoints)

      @fonts.load(codepoints, font_pixels)
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
      input = screen.input
      adjust(input.keys)
      key = LayoutKey.new(document.blocks, document.action_problem, screen.area)
      return unless wanted?(input, key)

      build(input, key, document)
    end

    private

    # Glyphs are rendered at the largest size on the page (Styles).
    #: () -> Integer
    def font_pixels
      @view.styles.font_pixels
    end

    # Zooming loads the fonts again at the new size; the header key only
    # changes what the next frame builds (a key press makes it due).
    #: (KeyPress keys) -> void
    def adjust(keys)
      return unless keys.pressed?

      view = @view.after(keys)
      resized = !view.same_size?(@view)
      @view = view
      zoom if resized
    end

    #: () -> void
    def zoom
      @fonts.reload(font_pixels)
      @cache.clear
    end

    #: (Input input, LayoutKey key) -> bool
    def wanted?(input, key)
      @scroll.note(input)
      @scroll.due? || !@cache.holds?(key)
    end

    # The document scrolls in the window area below the header.
    #: (Input input, LayoutKey key, DocumentView document) -> Frame
    def build(input, key, document)
      window = key.area
      header = header_for(key.blocks, window.width)
      area = window.below(header.height)
      content = content(key, area.width, document)
      Frame.of(content, header, scroll(input, content.height, area))
    end

    # A hidden header is one with no tasks to show: it takes no room.
    #: (Markdown::BlockList blocks, Float width) -> ProgressHeader
    def header_for(blocks, width)
      progress = @view.header? ? blocks.task_progress : Markdown::TaskProgress.new
      ProgressHeader.new(progress, @view.styles, width)
    end

    #: (LayoutKey key, Float width, DocumentView document) -> DrawList
    def content(key, width, document)
      return @cache.list if @cache.holds?(key)

      @cache.keep(key, Layout.new(@fonts, @view.styles, width).arrange(key.blocks, notices(document)))
    end

    # Applies this frame's input; returns the bar where the page ended up.
    #: (Input input, Float page_height, Rect area) -> Scrollbar
    def scroll(input, page_height, area)
      bar = Scrollbar.new(page_height, area, @scroll.offset)
      bar.moved_to(@scroll.apply(input, bar))
    end

    #: (DocumentView document) -> Array[String]
    def notices(document)
      (@fonts.notices + document.notices).uniq
    end
  end
end
