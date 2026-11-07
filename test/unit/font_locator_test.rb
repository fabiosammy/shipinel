# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/font_locator"

class FontLocatorTest < Minitest::Test
  # Answers like fc-match, without asking it.
  class FakeFontconfig
    def file_for(pattern) = "/fonts/#{pattern}.ttf"
  end

  def locate(requested, emoji = nil)
    Shipinel::FontLocator.new(FakeFontconfig.new).locate(Shipinel::Options.new("a.md", requested, 20, emoji))
  end

  def test_fontconfig_picks_both_fonts_by_default
    fonts = locate(nil)

    assert_equal ["/fonts/sans.ttf", "/fonts/sans:bold.ttf", "/fonts/monospace.ttf"],
                 [fonts.body, fonts.bold, fonts.mono]
  end

  def test_requested_font_is_used_for_body_and_bold_text
    fonts = locate(__FILE__)

    assert_equal [__FILE__, __FILE__], [fonts.body, fonts.bold]
  end

  def test_missing_requested_font_is_a_usage_error
    error = assert_raises(Shipinel::UsageError) { locate("/no/such/font.ttf") }

    assert_equal "--font /no/such/font.ttf: no such file", error.message
  end

  def test_real_fontconfig_answers_with_a_font_file
    skip "fc-match is not installed" unless system("command -v fc-match > /dev/null")

    assert_match(/\.(ttf|otf|ttc|pcf\.gz)\z/, Shipinel::Fontconfig.new.file_for("sans"))
  end

  def test_first_loadable_skips_collections_and_bitmap_fonts
    listing = "/n/NotoSans-Regular.ttc\n/b/fixed.pcf.gz\n/d/DejaVuSans.TTF\n/s/Source.otf\n"

    assert_equal "/d/DejaVuSans.TTF", Shipinel::Fontconfig.first_loadable(listing)
  end

  def test_first_loadable_is_empty_when_nothing_fits
    assert_equal "", Shipinel::Fontconfig.first_loadable("/n/NotoSans-Regular.ttc\n")
  end

  def test_requested_emoji_font
    assert_equal __FILE__, locate(nil, __FILE__).symbol
  end

  def test_missing_emoji_font_is_a_usage_error
    error = assert_raises(Shipinel::UsageError) { locate(nil, "/no/emoji.ttf") }

    assert_equal "--emoji-font /no/emoji.ttf: no such file", error.message
  end
end
