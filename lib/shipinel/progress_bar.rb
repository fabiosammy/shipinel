# frozen_string_literal: true

# The header's progress: "12 of 40 tasks done · 30%" above a bar filled by
# that share (green when done, amber when more than a workday behind the
# week), with a tick across the bar where the week is (WeekProgress).

require_relative "draw_list"
require_relative "geometry"
require_relative "theme"
require_relative "week_progress"

module Shipinel
  # See the file comment.
  class ProgressBar
    # The bar's thickness, and the gap between the label and the bar.
    BAR = 4.0
    GAP = 8.0
    # The pace tick's width, and how far it reaches above and below the bar.
    PACE_MARK = 2.0

    # @rbs @progress: WeekProgress
    # @rbs @style: TextStyle
    # @rbs @rect: Rect

    # `rect` is where the label's line and the bar go, the window's width
    # less the margins.
    #: (WeekProgress progress, TextStyle style, Rect rect) -> void
    def initialize(progress, style, rect)
      @progress = progress
      @style = style
      @rect = rect
    end

    # The label's line, the gap and the bar.
    #: (TextStyle style) -> Float
    def self.height(style)
      style.line_height + GAP + BAR
    end

    #: (DrawList overlay) -> void
    def add_to(overlay)
      overlay.add(TextRun.new(@progress.label, @rect, @style))
      bar = Rect.new(@rect.left, @rect.top + @style.line_height + GAP, @rect.width, BAR)
      add_bar(overlay, bar)
      add_pace_mark(overlay, bar)
    end

    private

    # The track, and the share filled in its color.
    #: (DrawList overlay, Rect bar) -> void
    def add_bar(overlay, bar)
      overlay.add(Box.new(bar, Theme::Progress::TRACK))
      overlay.add(Box.new(bar.left_part(@progress.share), @progress.color))
    end

    # A tick across the bar where the week is.
    #: (DrawList overlay, Rect bar) -> void
    def add_pace_mark(overlay, bar)
      overlay.add(Box.new(bar.tick_at(@progress.expected, PACE_MARK, PACE_MARK), Theme::Pace::MARK))
    end
  end
end
