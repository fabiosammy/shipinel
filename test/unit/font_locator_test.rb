# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/font_locator"

class FontLocatorTest < Minitest::Test
  # Answers like fc-match, without asking it.
  class FakeFontconfig
    def file_for(pattern) = "/fonts/#{pattern}.ttf"
  end

  def locate(requested)
    Shipinel::FontLocator.new(FakeFontconfig.new).locate(requested)
  end

  def test_fontconfig_picks_both_fonts_by_default
    fonts = locate(nil)

    assert_equal ["/fonts/sans.ttf", "/fonts/monospace.ttf"], [fonts.body, fonts.mono]
  end

  def test_requested_font_is_used_for_body_text
    assert_equal __FILE__, locate(__FILE__).body
  end

  def test_missing_requested_font_is_a_usage_error
    error = assert_raises(Shipinel::UsageError) { locate("/no/such/font.ttf") }

    assert_equal "--font /no/such/font.ttf: no such file", error.message
  end

  def test_real_fontconfig_answers_with_a_font_file
    skip "fc-match is not installed" unless system("command -v fc-match > /dev/null")

    assert_match(/\.(ttf|otf|ttc|pcf\.gz)\z/, Shipinel::Fontconfig.new.file_for("sans"))
  end
end
