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

  def test_undo_flips_the_last_tick_back_once
    @view.toggle(Shipinel::TaskClick.new(0, false))
    first = @view.undo.status
    second = @view.undo.status

    assert_equal [:toggled, :nothing, "- [ ] Reunião\n"], [first, second, File.read(@path)]
  end

  def test_nothing_to_undo_before_a_tick
    assert_equal :nothing, @view.undo.status
  end

  # The same safe toggle: a line changed since the tick is left alone.
  def test_undo_leaves_a_line_changed_since_alone
    @view.toggle(Shipinel::TaskClick.new(0, false))
    File.write(@path, "- [ ] Reunião, remarcada\n")

    assert_equal [:line_changed, "- [ ] Reunião, remarcada\n"], [@view.undo.status, File.read(@path)]
  end

  def test_a_failed_save_cannot_be_undone
    @view.toggle(Shipinel::TaskClick.new(0, true))

    assert_equal :nothing, @view.undo.status
  end

  def test_toggle_writes_and_shows_the_new_state
    result = @view.toggle(Shipinel::TaskClick.new(0, false))

    assert_equal [:toggled, true], [result.status, first_task_checked?]
  end

  def test_a_readable_file_has_no_notices
    assert_empty @view.notices
  end

  def test_missing_file_shows_the_reason_and_an_empty_page
    File.unlink(@path)
    @view.reload

    assert_equal 0, @view.blocks.size
    assert_match(/does not exist/, @view.notices.first)
  end

  def test_file_that_reappears_is_shown_again
    File.unlink(@path)
    @view.reload
    File.write(@path, "- [x] Reunião\n")
    @view.reload

    assert_equal [[], true], [@view.notices, first_task_checked?]
  end

  def test_failed_save_is_a_notice_until_the_file_changes
    skip "root ignores directory permissions" if Process.uid.zero?
    File.chmod(0o555, @dir)
    @view.toggle(Shipinel::TaskClick.new(0, false))
    File.chmod(0o755, @dir)

    assert_match(/\ACannot save /, @view.notices.first)
    File.write(@path, "- [ ] Outra\n")
    @view.reload

    assert_empty @view.notices
  end

  def test_a_link_to_a_place_in_the_same_file_opens_nothing
    @view.follow("#goal-1")

    assert_empty @view.notices
  end

  def test_shown_text_includes_the_notices
    File.unlink(@path)
    @view.reload

    assert_match(/does not exist/, @view.shown_text)
  end
end
