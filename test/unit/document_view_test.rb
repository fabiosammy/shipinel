# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/shipinel/document_view"

class DocumentViewTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, "- [ ] Reunião\n")
    @view = Shipinel::DocumentView.new(Shipinel::DocumentFile.new(@path))
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def first_task_checked?
    @view.blocks.at(0).checked?
  end

  def test_parses_the_file
    assert_equal [1, false], [@view.blocks.size, first_task_checked?]
  end

  def test_reload_without_changes_keeps_the_blocks
    blocks = @view.blocks
    @view.reload

    assert_same blocks, @view.blocks
  end

  def test_reload_picks_up_an_external_edit
    File.write(@path, "- [x] Reunião\n")
    @view.reload

    assert_predicate self, :first_task_checked?
  end

  def test_toggle_writes_and_shows_the_new_state
    result = @view.toggle(Shipinel::TaskClick.new(0, false))

    assert_equal [:toggled, true], [result.status, first_task_checked?]
  end

  def test_missing_file_shows_the_reason
    File.unlink(@path)
    @view.reload

    assert_match(/does not exist/, @view.blocks.at(0).text)
  end
end
