# frozen_string_literal: true

# Turns the command line into Options, or a UsageError explaining what is
# wrong with it. Pure Ruby: runs the same under CRuby and Spinel.

module Shipinel
  # A command line we cannot run with. The message is shown to the user.
  class UsageError < StandardError
  end

  # What the user asked for on the command line. `path` is "" when none
  # was given (the config's `file` is used then, Config#plan).
  class Options
    attr_reader :path #: String
    attr_reader :font_path #: String?
    attr_reader :font_size #: Integer
    attr_reader :emoji_font_path #: String?

    #: (String path, String? font_path, Integer font_size, String? emoji_font_path) -> void
    def initialize(path, font_path, font_size, emoji_font_path)
      @path = path
      @font_path = font_path
      @font_size = font_size
      @emoji_font_path = emoji_font_path
    end
  end

  # Reads `[PATH.md] [--font PATH] [--font-size N] [--emoji-font PATH]`, in
  # any order. A flag given twice keeps its last value.
  class CliOptions
    USAGE = "usage: shipinel [PATH.md] [--font PATH] [--font-size N] [--emoji-font PATH]"
    DEFAULT_FONT_SIZE = 20
    MIN_FONT_SIZE = 8
    MAX_FONT_SIZE = 72
    # Example match: "18"
    WHOLE_NUMBER = /\A\d+\z/

    # @rbs @args: Array[String]
    # @rbs @path: String?
    # @rbs @values: Hash[String, String]

    #: (Array[String] argv) -> void
    def initialize(argv)
      @args = argv.dup
      @path = nil
      @values = {}
    end

    #: () -> Options
    def parse
      take(@args.shift.to_s) until @args.empty?
      Options.new(@path.to_s, @values["--font"], font_size, @values["--emoji-font"])
    end

    private

    #: (String arg) -> void
    def take(arg)
      case arg
      when "--font", "--font-size", "--emoji-font" then @values[arg] = value_after(arg)
      else take_path(arg)
      end
      nil
    end

    #: (String flag) -> String
    def value_after(flag)
      raise UsageError, "#{flag} needs a value\n#{USAGE}" if @args.empty?

      @args.shift.to_s
    end

    #: () -> Integer
    def font_size
      text = @values.fetch("--font-size", DEFAULT_FONT_SIZE.to_s)
      size = WHOLE_NUMBER.match?(text) ? text.to_i : 0
      return size if size >= MIN_FONT_SIZE && size <= MAX_FONT_SIZE

      raise UsageError, "--font-size must be a whole number from #{MIN_FONT_SIZE} to #{MAX_FONT_SIZE}"
    end

    #: (String arg) -> void
    def take_path(arg)
      raise UsageError, "unknown option #{arg}\n#{USAGE}" if arg.start_with?("-")
      raise UsageError, "only one PATH.md is supported\n#{USAGE}" if @path

      @path = arg
    end
  end
end
