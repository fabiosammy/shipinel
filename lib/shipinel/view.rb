# frozen_string_literal: true

# What the user can change about how the page looks while it runs: the
# text size (zoomed with + and -, back with 0) and whether the progress
# header shows (h). Each change gives a new View.

require_relative "cli_options"
require_relative "keyboard"
require_relative "styles"

module Shipinel
  # See the file comment.
  class View
    # Pixels per zoom step.
    ZOOM_STEP = 2

    attr_reader :size #: Integer
    # The --font-size the window started with, which 0 goes back to.
    attr_reader :start_size #: Integer

    # @rbs @header: bool

    #: (Integer size, Integer start_size, bool header) -> void
    def initialize(size, start_size, header)
      @size = size
      @start_size = start_size
      @header = header
    end

    # The view a window opens with at --font-size `size`.
    #: (Integer size) -> View
    def self.starting_at(size)
      View.new(size, size, true)
    end

    #: () -> bool
    def header?
      @header
    end

    #: () -> Styles
    def styles
      Styles.new(@size.to_f)
    end

    # The view after this frame's keys.
    #: (KeyPress keys) -> View
    def after(keys)
      View.new(zoomed(keys), @start_size, keys.header? ? !@header : @header)
    end

    #: (View other) -> bool
    def same_size?(other)
      @size == other.size
    end

    private

    # Kept within the sizes --font-size allows (not written with `clamp`,
    # which Spinel widens: docs/spinel-notes.md).
    #: (KeyPress keys) -> Integer
    def zoomed(keys)
      return @start_size if keys.zoom_reset?

      size = @size + (keys.zoom_step * ZOOM_STEP)
      return CliOptions::MIN_FONT_SIZE if size < CliOptions::MIN_FONT_SIZE

      [size, CliOptions::MAX_FONT_SIZE].min
    end
  end
end
