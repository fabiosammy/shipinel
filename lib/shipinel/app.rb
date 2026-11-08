# frozen_string_literal: true

# Runs the window: opens it, loads the fonts, then each frame re-reads the
# file when it is time, lays the document out, draws it, and acts on a
# click: toggles the task in the file, or opens the link.

require_relative "document_file"
require_relative "document_view"
require_relative "draw_list"
require_relative "font_set"
require_relative "launch"
require_relative "frame"
require_relative "page"
require_relative "painter"
require_relative "poller"
require_relative "session"
require_relative "screen"
require_relative "theme"

module Shipinel
  # No window could be opened. The message is shown to the user.
  class WindowError < StandardError
  end

  # See the file comment.
  class App
    # KWin, Hyprland and GNOME rules match this exact title (README).
    TITLE = "shipinel"
    WIDTH = 440
    HEIGHT = 640
    NO_WINDOW = "could not open a window: no display (DISPLAY or WAYLAND_DISPLAY), or no OpenGL driver"

    # @rbs @screen: Screen
    # @rbs @document: DocumentView
    # @rbs @session: Session
    # @rbs @page: Page

    # A plan shown before opens as it was left; a new one at --font-size.
    #: (Screen screen, Launch launch) -> void
    def initialize(screen, launch)
      @screen = screen
      @document = DocumentView.new(DocumentFile.new(launch.path))
      @session = launch.session(WindowPlace.sized(WIDTH, HEIGHT))
      @page = Page.new(@session.saved.view, FontSet.new(screen.font_shim, launch.fonts))
    end

    # Raises WindowError when no window could be opened.
    #: () -> void
    def run
      @screen.open(@session.saved.place, TITLE)
      raise WindowError, NO_WINDOW unless @screen.ready?

      prepare
      tick until ending?
      finish
    end

    private

    # Fonts for the document's characters, back to where it was left, and
    # the tray icon.
    #: () -> void
    def prepare
      @page.prepare(@document, @session.saved)
      @session.desktop.start("Shipinel · #{@document.name}")
    end

    # The tray's Quit, or the close button unless it hides to the tray.
    #: () -> bool
    def ending?
      @session.desktop.ending?(@screen)
    end

    #: () -> void
    def finish
      remember
      @screen.close
    end

    # Saved whenever it changed (Session), so a killed window loses at most
    # half a second.
    #: () -> void
    def remember
      @session.save(@page.spot, @page.view, @screen.placement)
    end

    # One frame, 60 a second. The layout is reused until the file or the
    # window size changes, and an idle frame showing the same page is not
    # built or drawn again (Activity). A window shown again from the tray is
    # drawn in full.
    #: () -> void
    def tick
      chores if @session.due?(Clock.now_ms)
      @page.redraw if @session.desktop.reshown?
      respond(@screen.input)
    end

    # This frame's input: the page drawn (or not), a click acted on, and
    # `u` undoing the last tick.
    #: (Input input) -> void
    def respond(input)
      clicked = show(@page.update(input, @screen.placement.area, @document))
      act(clicked) if clicked
      saved(@document.undo) if input.keys.undo?
    end

    # Without a frame to draw, keeps the window responsive without drawing:
    # waits for input. When the window system lost the picture, the next
    # frame is drawn in full.
    #: (Frame? frame) -> DrawCommand?
    def show(frame)
      return draw(frame) if frame

      @page.redraw if @screen.skip_frame
      nil
    end

    #: () -> void
    def chores
      poll
      remember
      @session.desktop.remind(@document.blocks, @document.name)
    end

    # Picks up external edits: the page marks what changed and loads glyphs
    # for any new characters.
    #: () -> void
    def poll
      before = @document.content
      @document.reload
      @page.reloaded(before, @document)
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
      when Checkbox then saved(@document.toggle(command.click))
      when LinkArea then @document.follow(command.url)
      end
      # A problem notice may bring characters the fonts lack.
      @page.refresh_fonts(@document.shown_text)
    end

    # A tick, or its undo: a notification when it could not be saved.
    #: (ToggleResult result) -> void
    def saved(result)
      @session.desktop.save_failed(result.problem)
      nil
    end
  end
end
