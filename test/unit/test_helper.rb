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
