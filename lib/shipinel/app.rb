# frozen_string_literal: true

# Runs the window: opens it, loads the fonts, and draws frames until the
# user closes it. For now it shows the file's lines as plain text, read once
# at start; layout, clicks and reloading build on this.

require_relative "cli_options"
require_relative "document_file"
require_relative "font_locator"
require_relative "screen"
require_relative "theme"

module Shipinel
  # See the file comment.
  class App
    # KWin, Hyprland and GNOME rules match this exact title (README).
    TITLE = "shipinel"
    WIDTH = 440
    HEIGHT = 640
    MARGIN = 16.0
    # Line height as a multiple of the font size.
    LINE_SPACING = 1.4

    # @rbs @screen: Screen
    # @rbs @fonts: FontPaths
    # @rbs @style: TextStyle
    # @rbs @lines: Array[String]

    #: (Screen screen, Options options, FontPaths fonts) -> void
    def initialize(screen, options, fonts)
      @screen = screen
      @fonts = fonts
      @style = TextStyle.new(Theme::FontSlot::BODY, options.font_size.to_f, Theme::Ink::BODY)
      @lines = DocumentFile.new(options.path).read.lines_to_show
    end

    #: () -> void
    def run
      @screen.open(WIDTH, HEIGHT, TITLE)
      return unless @screen.ready?

      load_fonts
      draw_frame until @screen.closing?
      @screen.close
    end

    private

    #: () -> void
    def load_fonts
      size = @style.size.to_i
      @screen.load_font(Theme::FontSlot::BODY, @fonts.body, size)
      @screen.load_font(Theme::FontSlot::MONO, @fonts.mono, size)
      nil
    end

    #: () -> void
    def draw_frame
      @screen.begin_frame(Theme::Surface::BACKGROUND)
      draw_lines
      @screen.end_frame
    end

    #: () -> void
    def draw_lines
      top = MARGIN
      @lines.each do |line|
        @screen.draw_text(line, Point.new(MARGIN, top), @style)
        top += @style.size * LINE_SPACING
      end
      nil
    end
  end
end
