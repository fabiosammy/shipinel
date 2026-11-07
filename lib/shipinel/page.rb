# frozen_string_literal: true

# How the document is presented: its styles, where it is scrolled to, and
# warnings about fonts that could not be loaded. Each frame it lays the
# document out for the window's current size and applies the mouse wheel.

require_relative "document_view"
require_relative "draw_list"
require_relative "layout"
require_relative "screen"
require_relative "scroll"
require_relative "styles"

module Shipinel
  # See the file comment.
  class Page
    attr_reader :styles #: Styles

    # @rbs @scroll: Scroll
    # @rbs @font_notices: Array[String]

    #: (Styles styles) -> void
    def initialize(styles)
      @styles = styles
      @scroll = Scroll.new
      @font_notices = [""]
    end

    #: () -> Float
    def offset
      @scroll.offset
    end

    #: (String path) -> void
    def font_failed(path)
      @font_notices << "Could not load the font \"#{path}\" (raylib reads .ttf and .otf files): " \
                       "accented letters will not show in it. Try --font PATH."
      nil
    end

    #: (Screen screen, DocumentView document) -> DrawList
    def lay_out(screen, document)
      area = screen.area
      page = Layout.new(screen.text_measure, @styles, area.width).arrange(document.blocks, notices(document))
      @scroll.apply(screen.wheel_move, page.height, area.height)
      page
    end

    private

    #: (DocumentView document) -> Array[String]
    def notices(document)
      (@font_notices + document.notices).reject(&:empty?).uniq
    end
  end
end
