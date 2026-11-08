# frozen_string_literal: true

# Loads coverage first, then Minitest, for every unit test file under CRuby.

require "simplecov"

SimpleCov.start do
  enable_coverage :line
  add_filter "/test/"
  # ui.rb holds Spinel FFI declarations, which CRuby cannot load.
  add_filter "lib/shipinel/ui.rb"
  track_files "lib/**/*.rb"
  minimum_coverage line: 95
end

require "minitest/autorun"
require "tmpdir"

# State files (SavedState) go to a directory of the test run's own, never
# to the real ~/.local/state.
ENV["XDG_STATE_HOME"] = Dir.mktmpdir("shipinel-state")
