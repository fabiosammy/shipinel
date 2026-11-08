# frozen_string_literal: true

# What the command line and the config decided before the window opens:
# the plan, the --font-size, the fonts, and the settings.

require_relative "config"
require_relative "font_locator"
require_relative "session"
require_relative "view"

module Shipinel
  # See the file comment.
  class Launch
    attr_reader :path #: String
    attr_reader :view #: View
    attr_reader :fonts #: FontPaths
    attr_reader :config #: Config

    #: (String path, View view, FontPaths fonts, Config config) -> void
    def initialize(path, view, fonts, config)
      @path = path
      @view = view
      @fonts = fonts
      @config = config
    end

    # The plan's session: what it was left as, or `place` and --font-size
    # for a plan never shown before.
    #: (WindowPlace place) -> Session
    def session(place)
      Session.for(@path, SavedState.fresh(@view, place), @config)
    end
  end
end
