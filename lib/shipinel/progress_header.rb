# frozen_string_literal: true

# The strip pinned to the top of the window when the file has tasks: how
# many are done out of how many, and a bar filled by that share, green once
# every task is checked. It does not scroll with the page.

require_relative "draw_list"
require_relative "geometry"
require_relative "markdown/task_progress"
require_relative "styles"
require_relative "theme"

module Shipinel
  # See the file comment.
  class ProgressHeader
    # Pixels above the text, between the text and the bar, and below it.
    PADDING = 8.0
    BAR = 4.0

    # @rbs @progress: Markdown::TaskProgress
    # @rbs @style: TextStyle
    # @rbs @width: Float

    #: (Markdown::TaskProgress progress, Styles styles, Float width) -> void
    def initialize(progress, styles, width)
      @progress = progress
      @style = styles.status
      @width = width
    end

    # 0 for a file without tasks: it gets no header.
    #: () -> Float
    def height
      return 0.0 unless @progress.tasks?

      (PADDING * 3) + @style.line_height + BAR
    end

    # Into the overlay, which does not scroll.
    #: (DrawList overlay) -> void
    def add_to(overlay)
      return unless @progress.tasks?

      add_label(overlay, 0.0)
      add_bar(overlay, height - PADDING - BAR)
    end

    private

    #: (DrawList page, Float top) -> void
    def add_label(page, top)
      page.add(Box.new(Rect.new(0.0, top, @width, height), Theme::Progress::BAND))
      label = Rect.new(Theme::Spacing::MARGIN, top + PADDING, bar_width, @style.line_height)
      page.add(TextRun.new(@progress.label, label, @style))
    end

    #: (DrawList page, Float top) -> void
    def add_bar(page, top)
      width = bar_width
      page.add(Box.new(Rect.new(Theme::Spacing::MARGIN, top, width, BAR), Theme::Progress::TRACK))
      page.add(Box.new(Rect.new(Theme::Spacing::MARGIN, top, width * @progress.share, BAR), fill_color))
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
