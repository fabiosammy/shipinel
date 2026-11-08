# frozen_string_literal: true

# The file one plan's SavedState is kept in, and reading it back: lines of
# key=value under ~/.local/state/shipinel/ (or $XDG_STATE_HOME), one file
# per plan, named after its full path. A missing or unreadable file, or a
# value that does not fit, falls back to the defaults.

require_relative "key_values"
require_relative "saved_state"

module Shipinel
  # Reads a SavedState back from its text, falling back field by field.
  class StateReader
    # @rbs @fields: KeyValues

    #: (String text) -> void
    def initialize(text)
      @fields = KeyValues.new(text)
    end

    # `defaults` is what a new plan starts with; its view carries the
    # --font-size.
    #: (SavedState defaults) -> SavedState
    def state(defaults)
      SavedState.new(spot, view(defaults.view), place(defaults.place), StateDays.new(field("nudged"), field("day")))
    end

    private

    #: (String key) -> String
    def field(key)
      @fields[key]
    end

    #: () -> ScrollSpot
    def spot
      offset = field("offset")
      return ScrollSpot.none if offset.empty?

      ScrollSpot.new(field("section"), field("within").to_f, offset.to_f)
    end

    #: (View start) -> View
    def view(start)
      size = field("size").to_i
      size = start.size if size < CliOptions::MIN_FONT_SIZE || size > CliOptions::MAX_FONT_SIZE
      View.new(size, start.start_size, field("header") != "0")
    end

    #: (WindowPlace default_place) -> WindowPlace
    def place(default_place)
      width = field("width").to_f
      height = field("height").to_f
      return default_place unless width.positive? && height.positive?

      left = field("x")
      WindowPlace.new(Rect.new(left.to_f, field("y").to_f, width, height), !left.empty?)
    end
  end

  # The file one plan's state is kept in.
  class StateFile
    attr_reader :path #: String

    #: (String path) -> void
    def initialize(path)
      @path = path
    end

    # The state file for the plan at `plan_path`.
    #: (String plan_path) -> StateFile
    def self.for(plan_path)
      base = ENV.fetch("XDG_STATE_HOME", "")
      base = File.join(ENV.fetch("HOME", "/tmp"), ".local", "state") if base.empty?
      StateFile.new(File.join(base, "shipinel", File.expand_path(plan_path).tr("/", "%")))
    end

    # "" when there is no state yet or it cannot be read.
    #: () -> String
    def read
      File.read(@path)
    rescue SystemCallError
      ""
    end

    # Written to a temporary file and renamed over the old one, so a crash
    # never leaves half a file. The state is a convenience: when it cannot
    # be saved (a read-only home), the window carries on without it.
    #: (String text) -> void
    def write(text)
      make_directory(File.dirname(@path))
      replace(text)
    rescue SystemCallError
      nil
    end

    private

    #: (String text) -> void
    def replace(text)
      temporary = "#{@path}.tmp"
      File.write(temporary, text)
      File.rename(temporary, @path)
      nil
    end

    # Like mkdir -p (FileUtils does not compile under Spinel without
    # widening, docs/spinel-notes.md).
    #: (String directory) -> void
    def make_directory(directory)
      return if Dir.exist?(directory)

      make_directory(File.dirname(directory))
      Dir.mkdir(directory)
      nil
    end
  end
end
