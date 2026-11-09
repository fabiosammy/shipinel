# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../rakelib/support/release_notes"

class ReleaseNotesTest < Minitest::Test
  COMMITS = [["feat(tray)!: drop the old menu (#9)", "aaa1111"], ["fix: keep the scroll (#8)", "bbb2222"],
             ["docs(readme): new screenshot", "ccc3333"], ["feat(view): show deleted lines", "ddd4444"],
             ["Merge branch main", "eee5555"]].freeze

  def notes(previous = "v0.2.0") = ReleaseNotes.markdown("fabiosammy/shipinel", "v0.3.0", previous, COMMITS)

  # Breaking changes first, then features, fixes, and the rest; a
  # section's own type is not repeated, other types are.
  def test_groups_the_commits_by_type
    assert_includes notes, <<~MARKDOWN
      ### Breaking changes

      - **tray**: drop the old menu (#9) (aaa1111)

      ### Features

      - **view**: show deleted lines (ddd4444)

      ### Fixes

      - keep the scroll (#8) (bbb2222)

      ### Other

      - docs: **readme**: new screenshot (ccc3333)
      - Merge branch main (eee5555)
    MARKDOWN
  end

  def test_install_lines_name_the_tag_and_the_files
    assert_includes notes, "https://github.com/fabiosammy/shipinel/releases/download/v0.3.0/shipinel-linux-x86_64"
    assert_includes notes, "`shipinel-linux-x86_64.tar.gz`"
    assert_includes notes, "nix profile install github:fabiosammy/shipinel/v0.3.0"
  end

  def test_the_changelog_compares_with_the_previous_tag
    assert_includes notes, "https://github.com/fabiosammy/shipinel/compare/v0.2.0...v0.3.0"
    assert_includes notes(nil), "https://github.com/fabiosammy/shipinel/commits/v0.3.0"
  end

  def test_nothing_since_the_previous_release
    assert_includes ReleaseNotes.markdown("o/r", "v1.0.1", "v1.0.0", []), "Nothing since the previous release."
  end
end
