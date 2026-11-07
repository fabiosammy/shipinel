# frozen_string_literal: true

# Decides which font files to load: the --font file if given (for body and
# bold text alike), otherwise fontconfig's "sans" and "sans:bold"; and
# fontconfig's "monospace" for code.
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

  # The font files chosen for body text, bold text and code.
  class FontPaths
    attr_reader :body #: String
    attr_reader :bold #: String
    attr_reader :mono #: String

    #: (String body, String bold, String mono) -> void
    def initialize(body, bold, mono)
      @body = body
      @bold = bold
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
      mono = @fontconfig.file_for("monospace")
      return FontPaths.new(@fontconfig.file_for("sans"), @fontconfig.file_for("sans:bold"), mono) unless requested
      raise UsageError, "--font #{requested}: no such file" unless File.file?(requested)

      FontPaths.new(requested, requested, mono)
    end
  end
end
