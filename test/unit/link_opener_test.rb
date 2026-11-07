# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../lib/shipinel/link_opener"

class LinkOpenerTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("shipinel")
    @log = File.join(@dir, "opened.log")
    # Stands in for xdg-open: writes down what it was asked to open.
    @launcher = File.join(@dir, "fake-open")
    File.write(@launcher, "#!/bin/sh\necho \"$1\" >> '#{@log}'\n")
    File.chmod(0o755, @launcher)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def opener = Shipinel::LinkOpener.new("/notes/todo", @launcher)

  def opened
    20.times { File.exist?(@log) ? break : sleep(0.05) }
    File.read(@log)
  end

  def test_urls_with_a_scheme_open_as_they_are
    assert_equal ["https://linear.app/x", "mailto:a@b.test"],
                 [opener.target_for("https://linear.app/x"), opener.target_for("mailto:a@b.test")]
  end

  def test_relative_links_are_files_next_to_the_plan
    assert_equal "/notes/todo/week-2026-10-26-runbook.md", opener.target_for("week-2026-10-26-runbook.md#goal-1")
  end

  def test_a_link_inside_the_same_file_opens_nothing
    assert_equal ["", ""], [opener.target_for("#goal-1"), opener.open("#goal-1")]
  end

  def test_open_hands_the_target_to_the_launcher_in_the_background
    assert_equal "", opener.open("https://x.test/a?b=1&c='$(touch /tmp/never)'")
    assert_equal "https://x.test/a?b=1&c='$(touch /tmp/never)'\n", opened
  end
end
