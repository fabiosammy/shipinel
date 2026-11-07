# frozen_string_literal: true

# Decides which font files to load: the --font file if given, otherwise
# fontconfig's answer for "sans"; and fontconfig's "monospace" for code.
# An empty path means "none found", and the window falls back to raylib's
# built-in font.

require_relative "cli_options"

module Shipinel
  # Asks fontconfig which file it would use for a pattern.
  class Fontconfig
    #: (String pattern) -> String
    def file_for(pattern)
      `fc-match -f '%{file}' '#{pattern}'`
    end
  end

  # The font files chosen for body text and for code.
  class FontPaths
    attr_reader :body #: String
    attr_reader :mono #: String

    #: (String body, String mono) -> void
    def initialize(body, mono)
      @body = body
      @mono = mono
    end
  end

  # See the file comment.
  class FontLocator
    # @rbs @fontconfig: Fontconfig

    #: (Fontconfig fontconfig) -> void
    def initialize(fontconfig)
      @fontconfig = fontconfig
    end

    #: (String? requested) -> FontPaths
    def locate(requested)
      FontPaths.new(body(requested), @fontconfig.file_for("monospace"))
    end

    private

    #: (String? requested) -> String
    def body(requested)
      return @fontconfig.file_for("sans") unless requested
      raise UsageError, "--font #{requested}: no such file" unless File.file?(requested)

      requested
    end
  end
end
