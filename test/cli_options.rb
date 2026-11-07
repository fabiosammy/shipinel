# frozen_string_literal: true

# spin snapshot test: CliOptions compiled by Spinel must print what CRuby prints.

require_relative "../lib/shipinel/cli_options"

# Prints the parsed options, or the usage error, for one command line.
class CliOptionsSnapshot
  #: (Array[String] argv) -> void
  def show(argv)
    puts "#{argv.join(' ')} => #{outcome(argv)}"
  end

  #: (Array[String] argv) -> String
  def outcome(argv)
    options = Shipinel::CliOptions.new(argv).parse
    "path=#{options.path} font=#{options.font_path.inspect} size=#{options.font_size} " \
      "emoji=#{options.emoji_font_path.inspect}"
  rescue Shipinel::UsageError => error
    "error: #{error.message.lines.first.to_s.chomp}"
  end
end

snapshot = CliOptionsSnapshot.new
snapshot.show(["plan.md"])
snapshot.show(["--font", "/f/DejaVuSans.ttf", "semana.md", "--font-size", "24"])
snapshot.show(["--font-size", "18", "ação.md"])
snapshot.show(["plan.md", "--emoji-font", "/e/NotoEmoji.ttf", "--emoji-font", "/e/Symbola.ttf"])
snapshot.show([])
snapshot.show(["a.md", "b.md"])
snapshot.show(["--verbose"])
snapshot.show(["plan.md", "--font"])
snapshot.show(["plan.md", "--font-size", "big"])
snapshot.show(["plan.md", "--font-size", "200"])
