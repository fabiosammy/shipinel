# frozen_string_literal: true

# Entry point: reads the command line and the config, picks the fonts, and
# runs the window.
# The only file that requires ui.rb (Spinel FFI), so it is never run by CRuby.

require_relative "../lib/shipinel/app"
require_relative "../lib/shipinel/cli_options"
require_relative "../lib/shipinel/config"
require_relative "../lib/shipinel/font_locator"
require_relative "../lib/shipinel/launch"
require_relative "../lib/shipinel/screen"
require_relative "../lib/shipinel/view"
require_relative "../lib/shipinel/ui"
require_relative "../lib/shipinel/version"

if Shipinel::CliOptions.version?(ARGV)
  puts "shipinel #{Shipinel::VERSION}"
  exit 0
end

begin
  options = Shipinel::CliOptions.new(ARGV).parse
  config = Shipinel::ConfigFile.read
  config.problems.each { |problem| warn "shipinel: #{Shipinel::ConfigFile.path}: #{problem}" }
  path = config.plan(options.path, Shipinel::ConfigFile.path)
  fonts = Shipinel::FontLocator.new(Shipinel::Fontconfig.new).locate(options)
  view = Shipinel::View.starting_at(options.font_size)
  Shipinel::App.new(Shipinel::Screen.new, Shipinel::Launch.new(path, view, fonts, config)).run
rescue Shipinel::UsageError => error
  warn error.message
  exit 2
rescue Shipinel::WindowError => error
  warn "shipinel: #{error.message}"
  exit 1
end
