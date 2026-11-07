# frozen_string_literal: true

# Entry point: reads the command line, picks the fonts, and runs the window.
# The only file that requires ui.rb (Spinel FFI), so it is never run by CRuby.

require_relative "../lib/shipinel/app"
require_relative "../lib/shipinel/cli_options"
require_relative "../lib/shipinel/font_locator"
require_relative "../lib/shipinel/screen"
require_relative "../lib/shipinel/styles"
require_relative "../lib/shipinel/ui"

begin
  options = Shipinel::CliOptions.new(ARGV).parse
  fonts = Shipinel::FontLocator.new(Shipinel::Fontconfig.new).locate(options)
  styles = Shipinel::Styles.new(options.font_size.to_f)
  Shipinel::App.new(Shipinel::Screen.new, options.path, styles, fonts).run
rescue Shipinel::UsageError => error
  warn error.message
  exit 2
end
