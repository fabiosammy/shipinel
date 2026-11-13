# frozen_string_literal: true

# Builds one frame of the page (Page#update decides that one is wanted):
# the header, the laid-out document, the find bar's and the focus's keys,
# which may go to a match or a checkbox, the scroll, and what is marked on
# the page (selection, matches, focus).

require_relative "content_cache"
require_relative "document_view"
require_relative "find_bar"
require_relative "frame"
require_relative "header"
require_relative "highlighter"
require_relative "input"
require_relative "outline_panel"
require_relative "page_in_view"
require_relative "scroll"
require_relative "typesetter"
require_relative "view"

module Shipinel
  # See the file comment. One FrameMaker makes one frame.
  class FrameMaker
    # @rbs @view: View
    # @rbs @typesetter: Typesetter
    # @rbs @scroll: Scroll
    # @rbs @highlighter: Highlighter

    #: (View view, Typesetter typesetter, Scroll scroll, Highlighter highlighter) -> void
    def initialize(view, typesetter, scroll, highlighter)
      @view = view
      @typesetter = typesetter
      @scroll = scroll
      @highlighter = highlighter
    end

    # The document scrolls in the window area below the header, which names
    # the section the page ended up in; the find bar is pinned to the
    # bottom of the window.
    #: (Input input, LayoutKey key, DocumentView document) -> Frame
    def build(input, key, document)
      header = Header.for(@view, key)
      content = @typesetter.page_for(key, @view.styles, document)
      bar = scrolled(input, content, key.below(header.height))
      title = header.titled(bar.section_in(content, document.name), @typesetter.fonts)
      finish(input, Frame.of(content, title, bar), key.area)
    end

    # The outline's panel and the find bar (at the bottom of `window`) into
    # `frame`'s overlay, and the selection and other marks onto it.
    #: (Input input, Frame frame, Rect window) -> Frame
    def finish(input, frame, window)
      outlined = frame.adding(panel(PageInView.new(frame.content, frame.view)))
      @highlighter.selecting(input, outlined, @highlighter.find_bar(@view, window))
    end

    # The outline as it is, over `page`, in the status text.
    #: (PageInView page) -> OutlinePanel
    def panel(page)
      OutlinePanel.new(@highlighter.marks.outline, page, @view.styles.status)
    end

    private

    # The find bar's keys first, which may go to a match; then the page
    # scrolls in `area`, less the strip at the bottom (find bar or status).
    #: (Input input, DrawList content, Rect area) -> Scrollbar
    def scrolled(input, content, area)
      shown = area.shortened(FindBar.room(@view.styles.status))
      calm = pointed(input, PageInView.new(content, Viewport.new(@scroll.offset, shown)))
      @scroll.bar_for(calm, content, shown)
    end

    # The outline's input first, which may jump to a section; then the find
    # bar's and the focus's keys, which may go to a match or a checkbox.
    # Returns the input left for scrolling: while the outline is open, the
    # keys move it, not the page.
    #: (Input input, PageInView page) -> Input
    def pointed(input, page)
      steer(@highlighter.outlining(input, panel(page)))
      calm = @highlighter.outline_open? ? input.without_keys : input
      steer(@highlighter.moved(calm.keys, page.content, page.view))
      calm
    end

    # Goes to `spot` unless it is ScrollSpot.none.
    #: (ScrollSpot spot) -> void
    def steer(spot)
      @scroll.aim(spot) if spot.aimed?
      nil
    end
  end
end
