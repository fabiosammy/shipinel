# Contributing to Shipinel

Thanks for helping. Shipinel keeps one week's work in view so you deliver
it, and it stays small on purpose: read
[What Shipinel is not](README.md#what-shipinel-is-not) before proposing a
feature.

## Issues first

- **Bugs**: open a [bug report](https://github.com/fabiosammy/shipinel/issues/new/choose)
  with the smallest Markdown that shows it, your desktop (and Wayland or
  X11) and what `shipinel` printed.
- **Ideas and bigger changes**: open an
  [idea](https://github.com/fabiosammy/shipinel/issues/new/choose) first, so
  we agree on the what before you spend time on the how. Small fixes can go
  straight to a pull request.
- **Security problems**: please don't open an issue; use
  [Report a vulnerability](https://github.com/fabiosammy/shipinel/security/advisories/new)
  instead.

## Making a change

1. Fork, and branch from `main`.
2. Set up the tools: `nix develop`, or [docs/development.md](docs/development.md)
   without Nix.
3. Keep the change small and about one thing: small pull requests get
   reviewed, large ones wait.
4. Every behaviour you add or change gets a unit test (Minitest, under
   `test/unit/`). Logic stays in plain Ruby; the C in `ext/` only draws,
   reads input and talks to the desktop.
5. Run the whole gate before you push:

   ```sh
   bundle exec rake check     # or: nix flake check
   ```

   It must pass with zero offenses. Thresholds are never relaxed: when a
   check complains, change the code. The few narrow exceptions, each with
   its reason, are in [docs/exceptions.md](docs/exceptions.md).
6. For a change you can see, try it in a window (the checklist in
   [docs/manual-testing.md](docs/manual-testing.md)) and add a screenshot to
   the pull request.
7. Update the README (and `docs/`) when users would notice the change: keys,
   config, Markdown, behaviour.

The code is Ruby compiled by [Spinel](https://github.com/matz/spinel), which
takes a subset of Ruby. When Spinel refuses something or warns about
widening, [docs/spinel-notes.md](docs/spinel-notes.md) most likely has the
rule, such as which method names to avoid.

## Commits and pull request titles

Titles are lowercase [Conventional Commits](https://www.conventionalcommits.org):
`type(scope): description`, for example `feat(tray): show the progress ring`
or `fix: keep the scroll position on reload`.

| Type | For |
|---|---|
| `feat` | Something users can now do or see |
| `fix` | Something that was wrong for users |
| `perf` | Faster or lighter, same behaviour |
| `refactor` | Code changes that change no behaviour |
| `docs` | README, docs/, comments |
| `test` | Tests only |
| `build`, `ci` | Nix, the Rakefile, the workflows |
| `chore` | Everything else, including releases |

Add `!` after the type (`feat!:`) for a change that breaks existing configs
or habits, and say what breaks in the description.

Pull requests are **squash-merged**, so the title becomes the commit on
`main` and a line of the release notes; the commits inside a pull request
can be anything.

## Pull requests

Fill in the template: what changed, where to start reviewing, and how to
test it. Two checks run on every pull request and must be green:

- **10 · Validate**: every quality gate (`nix flake check`), the Nix package
  build, and a start of the built binary.
- **11 · PR title**: the title is a lowercase Conventional Commit. Editing
  the title runs it again.
- **12 · Linux bundle** (part of 10): the bundle for people without Nix,
  built on Ubuntu 22.04 (`packaging/linux/build.sh`), started, and driven
  in a virtual display by the window test (`test/window/run.sh`).

`main` only takes pull requests with both checks green, squash-merged.

Every Monday, **30 · Update flake** opens (or refreshes) the pull request
`chore(flake): update flake.lock` with the newest nixpkgs. When a newer
tool rejects the code there, the fix goes on that branch.

A maintainer reviews, may ask for changes, and squash-merges.

## Releases

Maintainers release from `main`, with [semantic versions](https://semver.org):

1. Open a pull request `chore(release): 0.2.0` that sets the same version in
   `flake.nix` (the `shipinel` package), `spin.toml` and
   `lib/shipinel/version.rb`. `rake check` fails when they differ.
2. Merge it once **10 · Validate** passes.
3. In the Actions tab, run **20 · Release** on `main`. It runs every gate
   again, builds the package, and creates the GitHub Release `v0.2.0`. Its
   notes list every commit since the previous tag under Features, Fixes,
   Performance and Other (breaking changes first), which is why the titles
   follow Conventional Commits; preview them with
   `bundle exec rake release_notes[v0.2.0]`.

A version is released once; the workflow refuses a tag that exists.

## License

By contributing, you agree that your contribution is licensed under the
project's [MIT License](LICENSE).
