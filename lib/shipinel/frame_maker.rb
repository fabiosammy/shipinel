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
      @highlighter.selecting(input, Frame.of(content, title, bar), @highlighter.find_bar(@view, key.area))
    end

    private

    # The find bar's keys first, which may go to a match; then the page
    # scrolls in `area`, less the find bar while it is open.
    #: (Input input, DrawList content, Rect area) -> Scrollbar
    def scrolled(input, content, area)
      shown = area.shortened(FindBar.room(@view.styles.status))
      steer(@highlighter.moved(input.keys, content, Viewport.new(@scroll.offset, shown)))
      @scroll.bar_for(input, content, @highlighter.search.open? ? shown : area)
    end

    # Goes to `spot` unless it is ScrollSpot.none.
    #: (ScrollSpot spot) -> void
    def steer(spot)
      @scroll.aim(spot) if spot.aimed?
      nil
    end
  end
end
