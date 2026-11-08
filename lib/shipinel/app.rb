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
require_relative "frame"
require_relative "page"
require_relative "painter"
require_relative "poller"
require_relative "screen"
require_relative "view"
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

    #: (Screen screen, String path, View view, FontPaths fonts) -> void
    def initialize(screen, path, view, fonts)
      @screen = screen
      @document = DocumentView.new(DocumentFile.new(path))
      @page = Page.new(view, FontSet.new(screen.font_shim, fonts))
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
    end

    # One frame, 60 a second. The layout is reused until the file or the
    # window size changes, and an idle frame showing the same page is not
    # built or drawn again (Activity).
    #: () -> void
    def tick
      poll if @poller.due?(Clock.now_ms)
      clicked = show(@page.update(@screen, @document))
      act(clicked) if clicked
      nil
    end

    #: (Frame? frame) -> DrawCommand?
    def show(frame)
      frame ? draw(frame) : skip
    end

    # Keeps the window responsive without drawing: waits for input. When
    # the window system lost the picture, the next frame is drawn in full.
    #: () -> DrawCommand?
    def skip
      @page.redraw if @screen.skip_frame
      nil
    end

    # Picks up external edits, and loads glyphs for any new characters.
    # The characters are only collected when the file changed: a reload
    # parses into new blocks.
    #: () -> void
    def poll
      before = @document.blocks
      @document.reload
      @page.refresh_fonts(@document.shown_text) if changed_since?(before)
    end

    #: (Markdown::BlockList blocks) -> bool
    def changed_since?(blocks)
      !@document.blocks.equal?(blocks)
    end

    #: (Frame frame) -> DrawCommand?
    def draw(frame)
      @screen.begin_frame(Theme::Surface::BACKGROUND)
      clicked = Painter.new(@screen, frame).paint
      @screen.end_frame
      clicked
    end

    #: (DrawCommand command) -> void
    def act(command)
      case command
      when Checkbox then @document.toggle(command.click)
      when LinkArea then @document.follow(command.url)
      end
      # A problem notice may bring characters the fonts lack.
      @page.refresh_fonts(@document.shown_text)
    end
  end
end
