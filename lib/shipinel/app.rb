# frozen_string_literal: true

# Runs the window: opens it, loads the fonts, then each frame lays out the
# document, applies the mouse wheel, draws, and toggles a clicked task in
# the file.

require_relative "document_file"
require_relative "document_view"
require_relative "font_locator"
require_relative "layout"
require_relative "painter"
require_relative "screen"
require_relative "scroll"
require_relative "styles"
require_relative "theme"

module Shipinel
  # See the file comment.
  class App
    # KWin, Hyprland and GNOME rules match this exact title (README).
    TITLE = "shipinel"
    WIDTH = 440
    HEIGHT = 640

    # @rbs @screen: Screen
    # @rbs @styles: Styles
    # @rbs @document: DocumentView
    # @rbs @scroll: Scroll

    #: (Screen screen, String path, Styles styles) -> void
    def initialize(screen, path, styles)
      @screen = screen
      @styles = styles
      @document = DocumentView.new(DocumentFile.new(path))
      @scroll = Scroll.new
    end

    #: (FontPaths fonts) -> void
    def run(fonts)
      @screen.open(WIDTH, HEIGHT, TITLE)
      return unless @screen.ready?

      prepare(fonts)
      tick until @screen.closing?
      @screen.close
    end

    private

    #: (FontPaths fonts) -> void
    def prepare(fonts)
      pixels = @styles.font_pixels
      @screen.load_font(Theme::FontSlot::BODY, fonts.body, pixels)
      @screen.load_font(Theme::FontSlot::BOLD, fonts.bold, pixels)
      @screen.load_font(Theme::FontSlot::MONO, fonts.mono, pixels)
      @screen.style_checkboxes(Theme::Checkbox::BORDER, Theme::Checkbox::HOVER, Theme::Checkbox::CHECK)
    end

    # One frame. Laid out every frame: the window may have been resized, and
    # at 10 frames a second a page of text costs next to nothing.
    #: () -> void
    def tick
      page = arrange
      @scroll.apply(@screen.wheel_move, page.height, @screen.area.height)
      click = draw(page)
      @document.toggle(click) if click
      nil
    end

    #: () -> DrawList
    def arrange
      Layout.new(@screen.text_measure, @styles, @screen.area.width).arrange(@document.blocks)
    end

    #: (DrawList page) -> TaskClick?
    def draw(page)
      @screen.begin_frame(Theme::Surface::BACKGROUND)
      click = Painter.paint(@screen, page, @scroll.offset)
      @screen.end_frame
      click
    end
  end
end
