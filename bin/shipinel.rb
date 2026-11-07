# frozen_string_literal: true

# Entry point: reads the command line, then (from phase 4) opens the window.

require_relative "../lib/shipinel/cli_options"

begin
  options = Shipinel::CliOptions.new(ARGV).parse
  puts "shipinel: #{options.path} (window not implemented yet)"
rescue Shipinel::UsageError => error
  warn error.message
  exit 2
end
