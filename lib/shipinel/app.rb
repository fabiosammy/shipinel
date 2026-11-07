# frozen_string_literal: true

# Runs the window: opens it, loads the fonts, then each frame re-reads the
# file when it is time, lays the document out, draws it, and acts on a
# click: toggles the task in the file, or opens the link.

require_relative "document_file"
require_relative "document_view"
require_relative "draw_list"
require_relative "font_locator"
require_relative "font_set"
require_relative "font_shim"
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

    #: (Screen screen, String path, Styles styles, FontPaths fonts) -> void
    def initialize(screen, path, styles, fonts)
      @screen = screen
      @document = DocumentView.new(DocumentFile.new(path))
      @page = Page.new(styles, FontSet.new(screen.font_shim, fonts))
      @poller = Poller.new(Clock.now_ms)
    end

    #: () -> void
    def run
      @screen.open(WIDTH, HEIGHT, TITLE)
      return unless @screen.ready?

      prepare
      tick until @screen.closing?
      @screen.close
    end

    private

    #: () -> void
    def prepare
      @page.load_fonts(@document.shown_text)
      @screen.style_checkboxes(Theme::Checkbox::BORDER, Theme::Checkbox::HOVER, Theme::Checkbox::CHECK)
    end

    # One frame, ten times a second. Laid out every frame: the window may
    # have been resized, and a page of text costs next to nothing.
    #: () -> void
    def tick
      poll if @poller.due?(Clock.now_ms)
      clicked = draw(@page.lay_out(@screen, @document))
      act(clicked) if clicked
      nil
    end

    # Picks up external edits, and loads glyphs for any new characters.
    #: () -> void
    def poll
      @document.reload
      @page.refresh_fonts(@document.shown_text)
    end

    #: (DrawList page) -> DrawCommand?
    def draw(page)
      @screen.begin_frame(Theme::Surface::BACKGROUND)
      clicked = Painter.new(@screen, @page.offset).paint(page)
      @screen.end_frame
      clicked
    end

    #: (DrawCommand command) -> void
    def act(command)
      case command
      when Checkbox then @document.toggle(command.click)
      when LinkArea then @document.follow(command.url)
      end
      nil
    end
  end
end
