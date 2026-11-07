# frozen_string_literal: true

# Decides which font files to load: the --font file if given (for body and
# bold text alike), otherwise fontconfig's "sans" and "sans:bold";
# fontconfig's "monospace" for code; and --emoji-font, otherwise
# fontconfig's monochrome "emoji", for symbols the text fonts lack. raylib
# reads only .ttf and .otf files, so fontconfig's whole ranked list is asked
# for and the first such file taken: its top answer can be a .ttc collection
# (common on NixOS). An empty path means "none found", and that slot falls
# back to raylib's built-in font.

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

  # The font files chosen for body text, bold text, code, and symbols
  # (emoji) the text fonts lack.
  class FontPaths
    attr_reader :body #: String
    attr_reader :bold #: String
    attr_reader :mono #: String
    attr_reader :symbol #: String

    #: (String body, String bold, String mono, String symbol) -> void
    def initialize(body, bold, mono, symbol)
      @body = body
      @bold = bold
      @mono = mono
      @symbol = symbol
    end
  end

  # See the file comment.
  class FontLocator
    # @rbs @fontconfig: Fontconfig

    #: (Fontconfig fontconfig) -> void
    def initialize(fontconfig)
      @fontconfig = fontconfig
    end

    # Monochrome emoji only: raylib cannot draw colour (bitmap) emoji, so
    # a font like Noto Color Emoji would leave them blank.
    #: (Options options) -> FontPaths
    def locate(options)
      font = options.font_path
      emoji = pick(options.emoji_font_path, "--emoji-font", "emoji:color=false")
      mono = @fontconfig.file_for("monospace")
      FontPaths.new(pick(font, "--font", "sans"), pick(font, "--font", "sans:bold"), mono, emoji)
    end

    private

    # The file the user asked for with `flag`, or fontconfig's for `pattern`.
    #: (String? requested, String flag, String pattern) -> String
    def pick(requested, flag, pattern)
      return @fontconfig.file_for(pattern) unless requested
      raise UsageError, "#{flag} #{requested}: no such file" unless File.file?(requested)

      requested
    end
  end
end
