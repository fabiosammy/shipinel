# frozen_string_literal: true

# Entry point: reads the command line, picks the fonts, and runs the window.
# The only file that requires ui.rb (Spinel FFI), so it is never run by CRuby.

require_relative "../lib/shipinel/app"
require_relative "../lib/shipinel/cli_options"
require_relative "../lib/shipinel/font_locator"
require_relative "../lib/shipinel/screen"
require_relative "../lib/shipinel/view"
require_relative "../lib/shipinel/ui"

begin
  options = Shipinel::CliOptions.new(ARGV).parse
  fonts = Shipinel::FontLocator.new(Shipinel::Fontconfig.new).locate(options)
  view = Shipinel::View.starting_at(options.font_size)
  Shipinel::App.new(Shipinel::Screen.new, options.path, view, fonts).run
rescue Shipinel::UsageError => error
  warn error.message
  exit 2
end
