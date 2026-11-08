# frozen_string_literal: true

# The strip pinned to the top of the window. When the file has tasks, it
# shows how many are done out of how many and a bar filled by that share,
# green once every task is checked. Below that, always, the section the
# window is in: the last heading scrolled to or past the top, or the file's
# name above the first one. It does not scroll with the page, keeps its
# height while the page scrolls, and h hides it (View).

require_relative "content_cache"
require_relative "draw_list"
require_relative "font_set"
require_relative "geometry"
require_relative "markdown/task_progress"
require_relative "theme"
require_relative "title_fit"
require_relative "view"

module Shipinel
  # See the file comment.
  class Header
    # Pixels above each line, between the text and the bar, and at the end.
    PADDING = 8.0
    BAR = 4.0

    # @rbs @view: View
    # @rbs @progress: Markdown::TaskProgress
    # @rbs @width: Float
    # @rbs @title: String

    # `title` is the section line; Page sets it with `titled` once the page
    # is scrolled for this frame. (Not an optional parameter: Spinel does
    # not seed signatures that have one, docs/spinel-notes.md.)
    #: (View view, Markdown::TaskProgress progress, Float width, String title) -> void
    def initialize(view, progress, width, title)
      @view = view
      @progress = progress
      @width = width
      @title = title
    end

    # The header over the page a layout key describes: its tasks, at the
    # window's width.
    #: (View view, LayoutKey key) -> Header
    def self.for(view, key)
      Header.new(view, key.blocks.task_progress, key.area.width, "")
    end

    # 0 when hidden (h).
    #: () -> Float
    def height
      return 0.0 unless @view.header?

      progress_height + line_height + (PADDING * 2)
    end

    # The same header showing `title`, cut with "…" to fit the window.
    #: (String title, FontSet fonts) -> Header
    def titled(title, fonts)
      Header.new(@view, @progress, @width, TitleFit.new(fonts, section_style, bar_width).fit(title))
    end

    # Into the overlay, which does not scroll.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      return unless @view.header?

      overlay.add(Box.new(Rect.new(0.0, 0.0, @width, height), Theme::Progress::BAND))
      add_progress(overlay) if @progress.tasks?
      overlay.add(TextRun.new(@title, text_rect(PADDING + progress_height), section_style))
    end

    private

    #: () -> Float
    def line_height
      style.line_height
    end

    #: () -> TextStyle
    def style
      @view.styles.status
    end

    #: () -> TextStyle
    def section_style
      style.with_color(Theme::Ink::MUTED)
    end

    # The label and bar take a line, the bar and two paddings.
    #: () -> Float
    def progress_height
      @progress.tasks? ? line_height + BAR + (PADDING * 2) : 0.0
    end

    #: (Float top) -> Rect
    def text_rect(top)
      Rect.new(Theme::Spacing::MARGIN, top, bar_width, line_height)
    end

    #: (DrawList overlay) -> void
    def add_progress(overlay)
      overlay.add(TextRun.new(@progress.label, text_rect(PADDING), style))
      add_bar(overlay, PADDING + line_height + PADDING)
    end

    #: (DrawList overlay, Float top) -> void
    def add_bar(overlay, top)
      width = bar_width
      overlay.add(Box.new(Rect.new(Theme::Spacing::MARGIN, top, width, BAR), Theme::Progress::TRACK))
      overlay.add(Box.new(Rect.new(Theme::Spacing::MARGIN, top, width * @progress.share, BAR), fill_color))
    end

    #: () -> Float
    def bar_width
      @width - (2 * Theme::Spacing::MARGIN)
    end

    #: () -> Integer
    def fill_color
      @progress.complete? ? Theme::Progress::COMPLETE : Theme::Progress::FILL
    end
  end
end
