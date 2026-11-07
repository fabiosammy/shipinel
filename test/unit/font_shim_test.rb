# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_ui"
require_relative "../../lib/shipinel/font_shim"

class FontShimTest < Minitest::Test
  def setup
    Shipinel::UI.calls.clear
    @shim = Shipinel::FontShim.new
  end

  def test_loading_with_extra_codepoints
    @shim.use_codepoints([0x2192, 0x1F916])
    @shim.load(3, "/e.ttf", 32)

    assert_equal [[:extra_codepoints, [0x2192, 0x1F916], 2], [:load_font, 3, "/e.ttf", 32]], Shipinel::UI.calls
  end

  def test_queries
    refute @shim.loaded?(0)
    assert_equal([true, false, true], [0, 1, 3].map { |slot| @shim.draws?(0x2192, slot) })
    assert_in_delta 42.5, @shim.text_width("→", Shipinel::TextStyle.new(0, 20.0, 0))
  end
end
