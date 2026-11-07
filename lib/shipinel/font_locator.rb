# frozen_string_literal: true

# Decides which font files to load: the --font file if given (for body and
# bold text alike), otherwise fontconfig's "sans" and "sans:bold"; and
# fontconfig's "monospace" for code. raylib reads only .ttf and .otf files,
# so fontconfig's whole ranked list is asked for and the first such file
# taken: its top answer can be a .ttc collection (common on NixOS).
# An empty path means "none found", and the window falls back to raylib's
# built-in font.

require_relative "cli_options"

module Shipinel
  # Asks fontconfig which file it would use for a pattern. Static fonts are
  # preferred: a variable font loads as its default (regular) instance, so
  # "sans:bold" would come out not bold.
  class Fontconfig
    # A line of `fc-match -s` output that raylib can load.
    # Example match: "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    LOADABLE = /^.+\.(?:ttf|otf)$/i

    # The first loadable file in fontconfig's ranked listing, or "".
    #: (String listing) -> String
    def self.first_loadable(listing)
      listing[LOADABLE].to_s
    end

    #: (String pattern) -> String
    def file_for(pattern)
      Fontconfig.first_loadable(`fc-match -s -f '%{file}\n' '#{pattern}:variable=false'`)
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
