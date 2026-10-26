# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/cli_options"

class CliOptionsTest < Minitest::Test
  def parse(*argv)
    Shipinel::CliOptions.new(argv).parse
  end

  def usage_error(*argv)
    assert_raises(Shipinel::UsageError) { parse(*argv) }.message
  end

  def test_path_only_uses_default_font
    options = parse("plan.md")

    assert_equal "plan.md", options.path
    assert_nil options.font_path
    assert_equal Shipinel::CliOptions::DEFAULT_FONT_SIZE, options.font_size
  end

  def test_flags_in_any_order
    options = parse("--font-size", "24", "semana.md", "--font", "/fonts/DejaVuSans.ttf")

    assert_equal "semana.md", options.path
    assert_equal "/fonts/DejaVuSans.ttf", options.font_path
    assert_equal 24, options.font_size
  end

  def test_accented_path
    assert_equal "ação.md", parse("ação.md").path
  end

  def test_font_size_bounds_are_inclusive
    assert_equal 8, parse("a.md", "--font-size", "8").font_size
    assert_equal 72, parse("a.md", "--font-size", "72").font_size
  end

  def test_missing_path
    assert_match(/missing PATH\.md/, usage_error)
  end

  def test_second_path
    assert_match(/only one PATH\.md/, usage_error("a.md", "b.md"))
  end

  def test_unknown_option
    assert_match(/unknown option --verbose/, usage_error("a.md", "--verbose"))
  end

  def test_flag_without_value
    assert_match(/--font needs a value/, usage_error("a.md", "--font"))
  end

  def test_font_size_not_a_number
    assert_match(/--font-size must be/, usage_error("a.md", "--font-size", "big"))
  end

  def test_font_size_out_of_range
    assert_match(/--font-size must be/, usage_error("a.md", "--font-size", "7"))
    assert_match(/--font-size must be/, usage_error("a.md", "--font-size", "73"))
  end
end
