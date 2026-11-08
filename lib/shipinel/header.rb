# frozen_string_literal: true

# The strip pinned to the top of the window. When the file has tasks, it
# shows how many are done out of how many and a bar filled by that share,
# green once every task is checked. Below that, always, the section the
# window is in: the last heading scrolled to or past the top, or the file's
# name above the first one. It does not scroll with the page, keeps its
# height while the page scrolls, and h hides it (View).

require_relative "content_cache"
require_relative "anchor"
require_relative "draw_list"
require_relative "font_set"
require_relative "geometry"
require_relative "progress_bar"
require_relative "week_progress"
require_relative "theme"
require_relative "title_fit"
require_relative "view"
require_relative "wall_time"

module Shipinel
  # See the file comment.
  class Header
    # Pixels above each line and at the end.
    PADDING = 8.0

    # @rbs @view: View
    # @rbs @progress: WeekProgress
    # @rbs @width: Float
    # @rbs @title: String

    # `title` is the section line; Page sets it with `titled` once the page
    # is scrolled for this frame. (Not an optional parameter: Spinel does
    # not seed signatures that have one, docs/spinel-notes.md.)
    #: (View view, WeekProgress progress, Float width, String title) -> void
    def initialize(view, progress, width, title)
      @view = view
      @progress = progress
      @width = width
      @title = title
    end

    # The header over the page a layout key describes: its tasks against
    # the week as it is now (WeekProgress), at the window's width.
    #: (View view, LayoutKey key) -> Header
    def self.for(view, key)
      Header.new(view, WeekProgress.new(key.blocks.task_progress, WallTime.now.week_share), key.area.width, "")
    end

    # 0 when hidden (h).
    #: () -> Float
    def height
      return 0.0 unless @view.header?

      progress_height + line_height + (PADDING * 2)
    end

    # The same header showing the section line: its title cut with "…" so
    # that the count (" · 3 of 8") fits after it.
    #: (SectionLine line, FontSet fonts) -> Header
    def titled(line, fonts)
      tasks = line.tasks
      suffix = tasks.empty? ? "" : " · #{tasks}"
      room = bar_width - fonts.text_width(suffix, section_style)
      Header.new(@view, @progress, @width, "#{TitleFit.new(fonts, section_style, room).fit(line.title)}#{suffix}")
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

    # The label's line and the bar, and a padding below them.
    #: () -> Float
    def progress_height
      @progress.tasks? ? ProgressBar.height(style) + PADDING : 0.0
    end

    #: (Float top) -> Rect
    def text_rect(top)
      Rect.new(Theme::Spacing::MARGIN, top, bar_width, line_height)
    end

    #: (DrawList overlay) -> void
    def add_progress(overlay)
      ProgressBar.new(@progress, style, text_rect(PADDING)).add_to(overlay)
    end

    #: () -> Float
    def bar_width
      @width - (2 * Theme::Spacing::MARGIN)
    end
  end
end
