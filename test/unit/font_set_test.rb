# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"

class FontSetTest < Minitest::Test
  def test_codepoints_beyond_latin_each_once_without_joiners
    assert_equal [0x2192, 0x1F916], Shipinel::FontSet.codepoints_in("ação → 🤖️ → ‍")
  end

  def test_load_sets_the_codepoints_then_loads_every_slot
    shim = FakeShim.new
    Shipinel::FontSet.new(shim, PATHS).load([0x2192], 32)

    assert_equal [[:use, [0x2192]], [:load, 0, "/s.ttf", 32], [:load, 2, "/b.ttf", 32], [:load, 4, "/i.ttf", 32],
                  [:load, 1, "/m.ttf", 32], [:load, 3, "/e.ttf", 32]], shim.calls
  end

  def test_only_characters_the_body_font_lacks_are_symbols
    fonts = fake_font_set("→ 🤖")

    assert_equal [false, true, false], [fonts.symbol?(0x2192), fonts.symbol?(0x1F916), fonts.symbol?(0x41)]
  end

  def test_covers_only_the_loaded_characters
    fonts = fake_font_set("→")

    assert_equal [true, true, false], [fonts.covers?([0x2192]), fonts.covers?([]), fonts.covers?([0x2192, 0x1F916])]
  end

  def test_pieces_split_where_the_font_changes
    assert_equal ["feito ", "🤖🖊", " ok"], fake_font_set("🤖🖊").pieces("feito 🤖🖊 ok")
  end

  def test_measures_through_the_shim
    assert_in_delta 20.0, fake_font_set.text_width("ab", Shipinel::TextStyle.new(0, 20.0, 0))
  end

  def test_a_notice_per_failing_font_path
    notices = fake_font_set(failing: ["/m.ttf", "/e.ttf"]).notices

    assert_equal(["\"/m.ttf\"", "\"/e.ttf\""], notices.map { |notice| notice[/"[^"]*"/] })
  end
end
