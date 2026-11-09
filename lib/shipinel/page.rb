# frozen_string_literal: true

# How the document is presented: its View (text size, header), where it is
# scrolled to, and the fonts (with their warnings). Each frame it reads the
# input and applies the zoom and header keys; a frame
# that is due or shows a changed page applies the wheel and the scrollbar,
# reuses the document's layout unless something it depends on changed, and
# builds the overlay: progress header and scrollbar. Any other frame does
# nothing more. It also keeps what the page points out (Highlighter).

require_relative "document_view"
require_relative "draw_list"
require_relative "frame"
require_relative "header"
require_relative "highlighter"
require_relative "scroll_spot"
require_relative "screen"
require_relative "scroll"
require_relative "scrollbar"
require_relative "typesetter"
require_relative "view"

module Shipinel
  # See the file comment.
  class Page
    # What the user changed with the keys: text size and header.
    attr_reader :view #: View

    # @rbs @scroll: Scroll
    # @rbs @typesetter: Typesetter
    # @rbs @highlighter: Highlighter

    #: (View view, FontSet fonts) -> void
    def initialize(view, fonts)
      @view = view
      @scroll = Scroll.new
      @typesetter = Typesetter.new(fonts)
      @highlighter = Highlighter.new(Day.today)
    end

    # After a file poll, given what the file held before it: the lines
    # changed outside are marked and the date moves on (Highlighter; at
    # midnight the page goes to the new day's heading), and glyphs are
    # loaded for new characters. The characters are only
    # collected when the file changed.
    #: (String before, DocumentView document) -> void
    def reloaded(before, document)
      after = document.content
      steer(@highlighter.reloaded(before, after, document.blocks))
      refresh_fonts(document.shown_text) unless before == after
    end

    # Before the first frame: fonts for the document's characters, and the
    # place it was left; on a new day, today's heading instead.
    #: (DocumentView document, SavedState saved) -> void
    def prepare(document, saved)
      load_fonts(document.shown_text)
      aim(@highlighter.opening(saved, document.blocks))
    end

    # Glyphs are rendered at the largest size on the page (Styles), with
    # every character the document uses.
    #: (String text) -> void
    def load_fonts(text)
      @typesetter.load(text, @view.styles.font_pixels)
    end

    # Loads the fonts again only when the text uses new characters.
    #: (String text) -> void
    def refresh_fonts(text)
      @typesetter.refresh(text, @view.styles.font_pixels)
    end

    # Draws the next frame even if nothing changed.
    #: () -> void
    def redraw
      @typesetter.forget
    end

    # Where the page is scrolled to, as a section and how far into it.
    #: () -> ScrollSpot
    def spot
      ScrollSpot.at(@scroll.offset, @typesetter.last.anchors)
    end

    # Goes to `spot` once the page is laid out (the place saved last time).
    #: (ScrollSpot spot) -> void
    def aim(spot)
      @scroll.aim(spot)
    end

    # The frame to draw in the window's `area` after this frame's `input`,
    # or nil when nothing is to be drawn.
    #: (Input input, Rect area, DocumentView document) -> Frame?
    def update(input, area, document)
      adjust(input.keys)
      key = LayoutKey.new(document.blocks, document.action_problem, @highlighter.highlights, area)
      return unless wanted?(input, key)

      @typesetter.fresh(build(input, key, document), input)
    end

    private

    # Goes to `spot` unless it is ScrollSpot.none (nowhere to go).
    #: (ScrollSpot spot) -> void
    def steer(spot)
      aim(spot) if spot.aimed?
    end

    # Zooming loads the fonts again at the new size and stays in the same
    # section; the header key only changes what the next frame builds (a
    # key press makes it due).
    #: (KeyPress keys) -> void
    def adjust(keys)
      return unless keys.pressed?

      before = @view
      @view = before.after(keys)
      zoom(@view.size.to_f / before.size) unless @view.same_size?(before)
    end

    #: (Float ratio) -> void
    def zoom(ratio)
      @scroll.aim(spot.scaled(ratio))
      @typesetter.resize(@view.styles.font_pixels)
    end

    #: (Input input, LayoutKey key) -> bool
    def wanted?(input, key)
      @scroll.note(input)
      @scroll.due? || !@typesetter.holds?(key)
    end

    # The document scrolls in the window area below the header, which names
    # the section the page ended up in.
    #: (Input input, LayoutKey key, DocumentView document) -> Frame
    def build(input, key, document)
      header = Header.for(@view, key)
      content = @typesetter.page_for(key, @view.styles, document)
      bar = @scroll.bar_for(input, content, key.area.below(header.height))
      Frame.of(content, header.titled(content.section_at(bar.offset, document.name), @typesetter.fonts), bar)
    end
  end
end
