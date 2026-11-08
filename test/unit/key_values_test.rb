# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../lib/shipinel/key_values"

class KeyValuesTest < Minitest::Test
  def test_lines_comments_and_blanks
    values = Shipinel::KeyValues.new("# a comment\n\nsize = 22\nnot a setting\nfile=a=b.md\nsize=24\n")

    assert_equal ["24", "a=b.md", "", %w[size file]], [values["size"], values["file"], values["missing"], values.keys]
  end
end
