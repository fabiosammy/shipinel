<!--
Title: a lowercase Conventional Commit, e.g. "feat(tray): show the progress ring".
The pull request is squash-merged, so the title becomes the commit on main.
-->

Closes #

## What changed

<!-- One or two sentences: what it does now. Why lives in the issue. -->

## Review notes

<!--
Where to start reading, decisions that are not obvious, and what this
intentionally does NOT do. Longer detail can go in a <details> block.
-->

- Start reviewing at:

## How to test and screenshots

<!-- Steps someone can follow cold. N/A for screenshots without a visible change. -->

1.

## Checklist

- [ ] `bundle exec rake check` (or `nix flake check`) passes with no offenses
- [ ] New or changed behaviour has unit tests
- [ ] A visible change was tried in a window (docs/manual-testing.md) and has a screenshot above
- [ ] README and docs/ say what changed for users (keys, config, Markdown, behaviour)
- [ ] It stays within [What Shipinel is not](https://github.com/fabiosammy/shipinel#what-shipinel-is-not)
