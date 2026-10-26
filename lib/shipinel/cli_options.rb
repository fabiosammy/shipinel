# frozen_string_literal: true

# Turns the command line into Options, or a UsageError explaining what is
# wrong with it. Pure Ruby: runs the same under CRuby and Spinel.

module Shipinel
  # A command line we cannot run with. The message is shown to the user.
  class UsageError < StandardError
  end

  # What the user asked for on the command line.
  class Options
    attr_reader :path #: String
    attr_reader :font_path #: String?
    attr_reader :font_size #: Integer

    #: (String path, String? font_path, Integer font_size) -> void
    def initialize(path, font_path, font_size)
      @path = path
      @font_path = font_path
      @font_size = font_size
    end
  end

  # Reads `PATH.md [--font PATH] [--font-size N]`, in any order.
  class CliOptions
    USAGE = "usage: shipinel PATH.md [--font PATH] [--font-size N]"
    DEFAULT_FONT_SIZE = 20
    MIN_FONT_SIZE = 8
    MAX_FONT_SIZE = 72
    # Example match: "18"
    WHOLE_NUMBER = /\A\d+\z/

    # @rbs @args: Array[String]
    # @rbs @path: String?
    # @rbs @font_path: String?
    # @rbs @font_size: Integer

    #: (Array[String] argv) -> void
    def initialize(argv)
      @args = argv.dup
      @path = nil
      @font_path = nil
      @font_size = DEFAULT_FONT_SIZE
    end

    #: () -> Options
    def parse
      take(@args.shift.to_s) until @args.empty?
      Options.new(path, @font_path, @font_size)
    end

    private

    #: () -> String
    def path
      found = @path
      raise UsageError, "missing PATH.md\n#{USAGE}" unless found

      found
    end

    #: (String arg) -> void
    def take(arg)
      case arg
      when "--font" then @font_path = value_after("--font")
      when "--font-size" then take_font_size(value_after("--font-size"))
      else take_path(arg)
      end
      nil
    end

    #: (String flag) -> String
    def value_after(flag)
      raise UsageError, "#{flag} needs a value\n#{USAGE}" if @args.empty?

      @args.shift.to_s
    end

    #: (String value) -> void
    def take_font_size(value)
      @font_size = WHOLE_NUMBER.match?(value) ? value.to_i : 0
      check_font_size
    end

    #: () -> void
    def check_font_size
      return if @font_size >= MIN_FONT_SIZE && @font_size <= MAX_FONT_SIZE

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
