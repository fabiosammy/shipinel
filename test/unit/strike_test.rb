# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/fake_fonts"
require_relative "../../lib/shipinel/layout"
require_relative "../../lib/shipinel/markdown/parser"

# ~~text~~: the line goes over the text (after it), 0.6 of the size below
# the top of its line, in the text's color. Size 20, fake font 10 px wide.
class StrikeTest < Minitest::Test
  STYLES = Shipinel::Styles.new(20.0)

  def page
    Shipinel::Layout.new(fake_font_set, STYLES, 400.0).arrange(Shipinel::Markdown::Parser.parse("~~feito~~"), [])
  end

  def test_line_over_the_text
    text = page.at(0)
    line = page.at(1).rect

    assert_equal ["feito", 16.0, 28.0, 50.0, 1.0], [text.text, line.left, line.top, line.width, line.height]
  end

  def test_line_in_the_text_color
    assert_equal Shipinel::Theme::Ink::BODY, page.at(1).color
  end
end
