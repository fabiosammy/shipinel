# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/shipinel/document_file"

class DocumentFileTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("shipinel")
    @path = File.join(@dir, "semana.md")
  end

  def teardown
    FileUtils.chmod_R(0o700, @dir)
    FileUtils.remove_entry(@dir)
  end

  def file
    Shipinel::DocumentFile.new(@path)
  end

  def leftovers
    Dir.children(@dir).grep(/shipinel-tmp/)
  end

  def test_read_returns_content_exactly
    File.write(@path, "- [ ] Reunião\r\nsem fim")

    assert_equal Shipinel::Snapshot.new("- [ ] Reunião\r\nsem fim", "").content, file.read.content
    assert_predicate file.read, :readable?
  end

  def test_missing_file_is_a_friendly_problem
    snapshot = file.read

    refute_predicate snapshot, :readable?
    assert_equal "#{@path} does not exist. Waiting for it to appear.", snapshot.problem
  end

  def test_unreadable_path_reports_the_reason
    Dir.mkdir(@path)

    assert_match(/\ACannot read .*semana\.md: Is a directory/, file.read.problem)
  end

  def test_snapshots_compare_content_and_problem
    a = Shipinel::Snapshot.new("x", "")

    assert a.same_as?(Shipinel::Snapshot.new("x", ""))
    refute a.same_as?(Shipinel::Snapshot.new("y", ""))
    refute a.same_as?(Shipinel::Snapshot.new("x", "gone"))
  end

  def test_write_replaces_content_and_keeps_permissions
    File.write(@path, "old")
    File.chmod(0o640, @path)

    assert_equal "", file.write("- [x] ação\r\n")
    assert_equal "- [x] ação\r\n", File.read(@path)
    assert_equal 0o640, File.stat(@path).mode & 0o777
  end

  def test_write_goes_through_a_symlink
    target = File.join(@dir, "real.md")
    File.write(target, "old")
    File.symlink("real.md", @path)
    file.write("new")

    assert File.symlink?(@path)
    assert_equal "new", File.read(target)
  end

  def test_write_leaves_no_temp_file
    File.write(@path, "old")
    file.write("new")

    assert_empty leftovers
  end

  def test_failed_write_keeps_the_original
    skip "root ignores directory permissions" if Process.uid.zero?
    File.write(@path, "original")
    File.chmod(0o555, @dir)

    assert_match(/\ACannot save .*semana\.md: Permission denied/, file.write("new"))
    assert_equal "original", File.read(@path)
  end

  def test_failed_rename_removes_the_temp_file
    Dir.mkdir(@path)

    assert_match(/\ACannot save /, file.write("new"))
    assert_empty leftovers
  end

  def test_write_to_a_deleted_file_fails
    assert_match(/\ACannot save .*No such file or directory/, file.write("new"))
  end
end
