# frozen_string_literal: true

# How the document is presented: its styles, where it is scrolled to, and a
# warning about the font if it could not be loaded. Each frame it lays the
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
    # @rbs @font_notice: String

    #: (Styles styles) -> void
    def initialize(styles)
      @styles = styles
      @scroll = Scroll.new
      @font_notice = ""
    end

    #: () -> Float
    def offset
      @scroll.offset
    end

    #: (String path) -> void
    def font_failed(path)
      @font_notice = "Could not load the font \"#{path}\": accented letters will not show. Try --font PATH."
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
      ([@font_notice] + document.notices).reject(&:empty?).uniq
    end
  end
end
