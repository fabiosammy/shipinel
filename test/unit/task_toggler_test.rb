# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/shipinel/task_toggler"

class TaskTogglerTest < Minitest::Test
  PLAN = "# Semana\n- [ ] Reunião\n  * [X] Pauta\n```\n- [ ] código\n```\n"

  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
    File.write(@path, PLAN)
  end

  def teardown
    FileUtils.chmod_R(0o700, @dir)
    FileUtils.remove_entry(@dir)
  end

  def toggle(line_index, checked)
    Shipinel::TaskToggler.new(Shipinel::DocumentFile.new(@path)).toggle(Shipinel::TaskClick.new(line_index, checked))
  end

  def test_checks_an_unchecked_task
    assert_equal :toggled, toggle(1, false).status
    assert_equal PLAN.sub("- [ ] Reunião", "- [x] Reunião"), File.read(@path)
  end

  def test_unchecks_an_uppercase_x
    toggle(2, true)

    assert_equal PLAN.sub("* [X] Pauta", "* [ ] Pauta"), File.read(@path)
  end

  def test_keeps_crlf_and_missing_final_newline
    File.write(@path, "- [ ] a\r\n- [ ] b")
    toggle(1, false)

    assert_equal "- [ ] a\r\n- [x] b", File.read(@path)
  end

  def test_only_the_checkbox_changes
    File.write(@path, "- [ ] ler [ ] e [x] depois\n")
    toggle(0, false)

    assert_equal "- [x] ler [ ] e [x] depois\n", File.read(@path)
  end

  def test_line_changed_underneath_is_left_alone
    File.write(@path, PLAN.sub("- [ ] Reunião", "Reunião cancelada"))

    assert_equal :line_changed, toggle(1, false).status
    assert_equal PLAN.sub("- [ ] Reunião", "Reunião cancelada"), File.read(@path)
  end

  def test_state_changed_underneath_is_left_alone
    File.write(@path, PLAN.sub("- [ ] Reunião", "- [x] Reunião"))

    assert_equal :line_changed, toggle(1, false).status
    assert_equal PLAN.sub("- [ ] Reunião", "- [x] Reunião"), File.read(@path)
  end

  def test_task_inside_a_fence_is_never_toggled
    assert_equal :line_changed, toggle(4, false).status
    assert_equal PLAN, File.read(@path)
  end

  def test_fence_added_above_turns_the_task_into_code
    File.write(@path, "```\n#{PLAN}")

    assert_equal :line_changed, toggle(2, false).status
  end

  def test_line_past_the_end
    assert_equal :line_changed, toggle(99, false).status
  end

  def test_deleted_file_fails_with_the_reason
    File.unlink(@path)
    result = toggle(1, false)

    assert_equal :failed, result.status
    assert_match(/does not exist/, result.problem)
  end

  def test_write_failure_is_reported_and_file_kept
    skip "root ignores directory permissions" if Process.uid.zero?
    File.chmod(0o555, @dir)
    result = toggle(1, false)

    assert_equal [:failed, PLAN], [result.status, File.read(@path)]
    assert_match(/\ACannot save .*Permission denied/, result.problem)
  end
end
