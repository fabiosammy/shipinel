# frozen_string_literal: true

# The body of a GitHub release: how to install that version, and what
# changed since the previous tag, grouped by Conventional Commit type.
# Built from the commits themselves, so it says the same whether a change
# came in as a squash-merged pull request (its title is the commit) or as
# a direct push.

# See the file comment.
module ReleaseNotes
  # Example match: "feat(tray)!: show the ring (#12)" (type "feat", scope
  # "tray", breaking "!", text "show the ring (#12)")
  SUBJECT = /\A(?<type>[a-z]+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?: (?<text>.+)\z/

  # Section titles, in the order they are shown. Every other type goes
  # under "Other".
  SECTIONS = { "breaking" => "Breaking changes", "feat" => "Features", "fix" => "Fixes",
               "perf" => "Performance" }.freeze

  # `commits`: [subject, short sha] pairs, newest first (git log order).
  # `previous`: the tag before this one, or nil for the first release.
  def self.markdown(repo, tag, previous, commits)
    [install(repo, tag), changes(commits), changelog(repo, tag, previous)].join("\n\n")
  end

  def self.install(repo, tag)
    <<~TEXT.chomp
      Install or update with [Nix](https://nixos.org):

      ```sh
      nix profile install github:#{repo}/#{tag}
      ```

      or run it once: `nix run github:#{repo}/#{tag} -- ~/notes/week.md`.

      Without Nix (x86_64, glibc 2.35 or newer: Ubuntu 22.04, Debian 12,
      Fedora 36 and later): download `shipinel-#{tag.delete_prefix('v')}-linux-x86_64.tar.gz`
      below and follow the `INSTALL.md` inside.
    TEXT
  end

  def self.changes(commits)
    return "## What changed\n\nNothing since the previous release." if commits.empty?

    groups = commits.group_by { |subject, _sha| section_of(subject) }
    sections = (SECTIONS.values + ["Other"]).select { |title| groups.key?(title) }
    "## What changed\n\n#{sections.map { |title| section(title, groups[title]) }.join("\n\n")}"
  end

  def self.section(title, commits)
    "### #{title}\n\n#{commits.map { |subject, sha| entry(subject, sha) }.join("\n")}"
  end

  def self.section_of(subject)
    match = SUBJECT.match(subject)
    return "Other" unless match
    return SECTIONS["breaking"] if match[:breaking]

    SECTIONS.fetch(match[:type], "Other")
  end

  # "feat(tray): show the ring" becomes "**tray**: show the ring (abc1234)";
  # under Other the type stays, since it is not the section's.
  def self.entry(subject, sha)
    match = SUBJECT.match(subject)
    return "- #{subject} (#{sha})" unless match

    scope = match[:scope] ? "**#{match[:scope]}**: " : ""
    type = SECTIONS.key?(match[:type]) ? "" : "#{match[:type]}: "
    "- #{type}#{scope}#{match[:text]} (#{sha})"
  end

  def self.changelog(repo, tag, previous)
    return "**Full changelog**: https://github.com/#{repo}/commits/#{tag}" unless previous

    "**Full changelog**: https://github.com/#{repo}/compare/#{previous}...#{tag}"
  end
end
