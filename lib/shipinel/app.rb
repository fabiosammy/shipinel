# frozen_string_literal: true

# Runs the window: opens it, loads the fonts, then each frame re-reads the
# file when it is time, lays the document out, draws it, and toggles a
# clicked task in the file.

require_relative "document_file"
require_relative "document_view"
require_relative "font_locator"
require_relative "page"
require_relative "painter"
require_relative "poller"
require_relative "screen"
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
    # @rbs @document: DocumentView
    # @rbs @page: Page
    # @rbs @poller: Poller

    #: (Screen screen, String path, Styles styles) -> void
    def initialize(screen, path, styles)
      @screen = screen
      @document = DocumentView.new(DocumentFile.new(path))
      @page = Page.new(styles)
      @poller = Poller.new(Clock.now_ms)
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
      load_fonts(fonts)
      report_failed_fonts(fonts)
      @screen.style_checkboxes(Theme::Checkbox::BORDER, Theme::Checkbox::HOVER, Theme::Checkbox::CHECK)
    end

    # Each slot that fell back to raylib's built-in font gets a notice.
    #: (FontPaths fonts) -> void
    def report_failed_fonts(fonts)
      @page.font_failed(fonts.body) unless @screen.font_loaded?(Theme::FontSlot::BODY)
      @page.font_failed(fonts.bold) unless @screen.font_loaded?(Theme::FontSlot::BOLD)
      @page.font_failed(fonts.mono) unless @screen.font_loaded?(Theme::FontSlot::MONO)
    end

    # Glyphs are rendered at the largest size on the page (Styles).
    #: (FontPaths fonts) -> void
    def load_fonts(fonts)
      pixels = @page.styles.font_pixels
      @screen.load_font(Theme::FontSlot::BODY, fonts.body, pixels)
      @screen.load_font(Theme::FontSlot::BOLD, fonts.bold, pixels)
      @screen.load_font(Theme::FontSlot::MONO, fonts.mono, pixels)
    end

    # One frame, ten times a second. Laid out every frame: the window may
    # have been resized, and a page of text costs next to nothing.
    #: () -> void
    def tick
      @document.reload if @poller.due?(Clock.now_ms)
      click = draw(@page.lay_out(@screen, @document))
      @document.toggle(click) if click
      nil
    end

    #: (DrawList page) -> TaskClick?
    def draw(page)
      @screen.begin_frame(Theme::Surface::BACKGROUND)
      click = Painter.paint(@screen, page, @page.offset)
      @screen.end_frame
      click
    end
  end
end
