# Project: Shipinel

**Shipinel** ("ship it this week") is a small, always-visible desktop window
that renders a Markdown week plan and lets me tick its task checkboxes, so the
week's work stays in view while I deliver it. Written in Ruby, compiled to a
native binary with **Spinel** (https://github.com/matz/spinel), drawn with
**raylib + raygui** through Spinel's FFI, packaged with Nix.

Readability for humans is the top priority after correctness. Prefer boring,
obvious code over clever code.

The README is for users, contributors and developers; CONTRIBUTING.md is the
contribution process. This file is how you (Claude) work on the project.

---

## 1. Scope

### What it does

- `shipinel [PATH.md] [--font PATH] [--font-size N] [--emoji-font PATH]`;
  without a path, the config's `file` is opened. `--version` prints the
  version.
- One window titled exactly `shipinel` (KWin / Hyprland / GNOME rules match
  it, so the title must never change).
- Renders the file read-only, except task checkboxes: a click flips `[ ]` ↔
  `[x]` on that exact source line and saves the file. External edits show up
  within about a second.
- Markdown: headings, tasks (`-`/`*`/`+`, numbered, nested), bullets,
  paragraphs, `**bold**`, `*italic*`/`_italic_`, `~~strike~~`, `` `code` ``,
  links (click opens with `xdg-open`), tables, block quotes, rules, fenced
  code (never tasks), symbols and emoji (monochrome emoji font). The full
  table is in the README.
- Header: "N of M tasks done · P%", a progress bar with the week's pace
  (a tick where Monday 00:00 → Friday 24:00 is; amber when more than a
  workday behind; green when done), and the current section with its own
  count ("Goal 1 · 3 of 8"). `h` hides it.
- Today: the first heading holding today's date or starting with today's
  weekday (English/Portuguese, whole word) is in the accent color; a plan
  saved on another day (`day=` in its state) opens there, and so does an
  open window at midnight (Day, Highlighter).
- Focus marks: an open task with `⏳` or "(waiting" is waiting (italic,
  quieter; still counted); a `YYYY-MM-DD` before today in an open task is
  amber, today's in the accent color (Highlights#color_of); lines changed
  outside get a margin mark for 10 s, deleted ones a notch over the line
  that follows them (Highlights, LineChanges, RemovedLines; compared by
  content per poll, so own ticks never mark).
- Keys: `j`/`k`, arrows, Page Up/Down, Home/End, `+`/`-`/`0` zoom, `h`,
  `u` (undo the last tick once, through the same safe toggle).
- Select and copy: dragging over the page (or Ctrl+A) selects text in
  reading order (Selection, page positions, so it survives scrolling; a
  new layout drops it); Ctrl+C copies it, a line per laid-out line.
- Find: Ctrl+F opens a bar at the bottom; what is typed (raylib's typed
  characters) is found case-insensitively in the laid-out text, lines
  joined by a space (PageText, Matches); every match is highlighted, the
  current one brighter, with "2 of 7"; Enter / Shift+Enter step round,
  Escape closes. While open, letter commands are typed, not obeyed
  (KeyPress#while_finding).
- Scrollbar (wheel, drag, track click).
- Reopens each plan where it was left (section by heading slug, zoom,
  header, window size; position only on X11; the day it was saved) from
  `~/.local/state/shipinel/`.
- Config `~/.config/shipinel/config`: `file`, `notify_daily`,
  `notify_save_failed`, `tray`, `close_to_tray` (docs/config.example). Read
  again every chore (Desktop#follow_config): changes apply at once, the tray
  icon opening or closing; `file` only at the next start.
- Notifications through `notify-send`: a daily open-tasks nudge naming one
  open task that is not waiting, and a failed save.
- Tray icon (StatusNotifierItem + dbusmenu over sd-bus): progress ring and
  tooltip (with the open tasks overdue or due today, DueDates: a task's
  first date), click shows/hides the window, menu with Quit, optional close to
  tray; without a tray host, closing quits.
- TERM, INT and HUP end it like the close button (StopSignals: the trap
  sets a flag the loop reads), saving the state.
- Desktop entry and icon (`packaging/shipinel.desktop`, `.svg`) in the Nix
  package and the bundle; `rake desktop_checks` validates the entry. No
  Wayland app id (raylib resets GLFW's hints), so `StartupWMClass` only
  matches on X11.
- Idle costs next to no CPU (§3, Frames).

### What it is not (decided)

These are settled (README, "What Shipinel is not"). Do not propose or build
them; if an idea crosses one, say so:

- **Not an editor**: no typing, adding, moving or deleting tasks. The only
  write is a checkbox flip. (Typing into the find bar changes no file.)
- **No filtering or views**: the whole plan is shown as written. No tags,
  priorities, assignees, due-date engine, "open tasks only".
- **No timers**: no pomodoros, time tracking, focus sessions.
- **No history, stats or streaks.**
- **Not a service**: one local file, no accounts, sync or network (besides
  links I click and notifications).

### Decided

- Find highlights and never hides (2026-11-10): it is not filtering. It
  searches what is drawn, not the Markdown source.

- Tasks are not done in order, and some wait on others: no "next task"
  marker. Waiting is marked per task (`⏳`, "(waiting"), not by heading;
  the nudge names an example open task, never "the next one".

---

## 2. Before changing anything: verify, don't remember

- **Spinel** is young and takes a subset of Ruby. Read
  `docs/spinel-notes.md` before writing Ruby that Spinel compiles. When
  unsure whether a construct compiles cleanly, write a minimal probe and
  compile it with `spinel --warn-widen probe.rb -o probe` (and run it under
  CRuby too) before using it. Record every new finding in
  `docs/spinel-notes.md`.
- The traps that bit us, all in `docs/spinel-notes.md`:
  - Never name a method, attribute or local after an Enumerable/Comparable
    method: `count`, `find`, `index`, `detect`, `clamp`, `tally`,
    `partition`, `take`, ... The name alone pulls in widening builtins.
  - `grep_v`, `all?`, `none?`, `each_with_index`, `between?`,
    `String#partition` widen; `select`, `reject`, `map`, `min`/`max` don't.
  - No optional/rest parameters in typed methods; no typed constants
    (use a method returning the value); no annotated overrides.
  - A value narrowed by `is_a?` cannot be passed to a subclass-typed
    parameter: dispatch with `case` and read the fields there.
  - Object arrays stay typed only in an owner class's ivar, read by index.
  - Every path of a method returns the same type (end with `nil` for void).
- **Native signatures** are never guessed: copy them from the headers into
  `docs/raylib-notes.md` (raylib, raygui, GLFW) or `docs/tray-notes.md`
  (sd-bus, D-Bus interfaces) with file and line.

---

## 3. Architecture

Pure logic (runs identically under CRuby and Spinel, unit-tested) is kept
apart from the thin native layer.

| Part | Role |
|---|---|
| `bin/shipinel.rb` | Entry point: CLI, config, fonts, `App` (the only file requiring `ui.rb`) |
| `lib/shipinel/markdown/` | Parser: lines → blocks with source line index; inline spans |
| `layout.rb`, `flow.rb`, `line_wrap.rb`, `*_layout.rb`, `anchor.rb` | Blocks → draw commands for a width; heading anchors with task counts |
| `page.rb`, `frame_maker.rb`, `typesetter.rb`, `content_cache.rb`, `header.rb`, `progress_bar.rb`, `painter.rb` | One frame: cached layout, header, scrollbar, drawing, clicks |
| `day.rb`, `line_changes.rb`, `highlights.rb`, `highlighter.rb`, `ChangeMarks` in `draw_list.rb` | Today's heading, past dates, lines changed outside: kept per poll, marked while laying out |
| `selection.rb`, `reading_order.rb`, `selected_lines.rb`, `clipboard.rb` | Text selected with the mouse or Ctrl+A, and Ctrl+C |
| `search.rb`, `page_text.rb`, `matches.rb`, `match_maker.rb`, `span.rb`, `find_bar.rb`, `marks.rb` | The find bar (Ctrl+F): query, matches, the strip, marks drawn under the text |
| `app.rb`, `session.rb`, `desktop.rb`, `reminder.rb`, `tray_icon.rb` | Loop, file poll, saved state, notifications, tray |
| `task_toggler.rb`, `document_file.rb` | Safe toggle, atomic write |
| `config.rb`, `state_file.rb`, `key_values.rb` | Config and saved state (key=value) |
| `screen.rb`, `tray.rb`, `font_shim.rb`, `ui.rb` | Adapters over the FFI (fakes in tests) |
| `ext/ui_shim.c` | Window, drawing, input, fonts, frame pacing, waker thread (raylib, raygui, GLFW) |
| `ext/tray.c` | StatusNotifierItem + dbusmenu over sd-bus |

### Design rules

- **Parse by line, keep line numbers.** A click maps to a source line, never
  to "the n-th checkbox".
- **Safe toggling.** Re-read the file, verify the line is still that task in
  the expected state, flip only `[ ]`/`[x]`, write atomically (temp file +
  `File.rename`, permissions kept, symlinks written through), keep line
  endings and the final newline.
- **Change detection** by re-reading and comparing content about every
  500 ms. No inotify.
- **Native layer is dumb.** C takes scalars and strings only and holds the
  window, font and tray state; every decision is Ruby. Carried `.c` files
  listed in `spin.toml`, not `ffi_source`.
- **Frames.** Never `SetTargetFPS` (raylib's wait spins the CPU). A frame
  is drawn only when its Look (frame.rb: the laid-out page, where it sits,
  the clickable under the pointer, the button) differs from the last one
  drawn; drawn frames are paced at 60/s with `clock_nanosleep`. Any other
  frame, busy or idle, draws nothing and waits for input through raylib's
  event waiting, woken every 500 ms (file poll) or by the tray's bus by the
  waker thread. The layout is cached until blocks, window size, notices or
  fonts change; only visible commands are drawn. 20 wheel steps draw ~40
  frames, not ~1,250 (2026-11-09).
- **Window position** is only read/set on X11; on Wayland the compositor
  places windows (window rules in the README).
- **Fonts and accents.** TTF/OTF loaded with Latin-1 + Latin Extended-A plus
  the document's characters; symbols fall back to a monochrome emoji font.
- **Theme.** One dark theme, every color and spacing in `theme.rb`.
- **Desktop integration degrades**: no `notify-send` → stderr line; no tray
  host → stderr line and closing quits (the window can never get lost).

---

## 4. Quality gates

`bundle exec rake check` (and `nix flake check`, which runs it) must pass with
zero offenses before a change is done:

- Version: `flake.nix`, `spin.toml` and `lib/shipinel/version.rb` agree
  (`rake check_version`).
- YAML: workflows and issue forms pass `yamllint --strict` (`.yamllint`);
  workflows pass actionlint (with shellcheck); the shell scripts
  (`packaging/`, `test/window/`, `docs/demo/`) pass shellcheck.
- RuboCop (+ rubocop-performance, -rake, -minitest, rubocop_spinel), Reek,
  Flog (≤ 20 per method), Flay, RubyCritic (every file A or B), Steep with
  inline RBS, Minitest with SimpleCov (≥ 95% of `lib/` lines).
- C: `-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Werror`, clang-tidy,
  cppcheck, clang-format.
- Spinel: the app and `test/*.rb` compile with every widening warning as an
  error; `spinel diff` prints the same under CRuby and Spinel.

Never weaken a threshold or disable a check to pass. Refactor instead (split a
class, move behaviour to the object it envies, extract a value object). The
few narrow exceptions are in `docs/exceptions.md` and `.reek.yml`, each with
its reason; a new one needs a structural reason and my OK. If a threshold
seems wrong, stop and ask.

CI runs the same: `10 · Validate` (flake check, build, binary start, and
`12 · Linux bundle`: `packaging/linux/build.sh` on Ubuntu 22.04 (one
executable with raylib and GLFW linked statically, plus a tarball) and the
window test `test/window/run.sh` in Xvfb) and `11 · PR title` on every pull
request; `20 · Release` by hand (attaches `shipinel-linux-x86_64`, the
tarball and SHA256SUMS, names without a version for `latest/download`); `30 · Update
flake` opens the weekly flake.lock pull request (and starts 10 on it, since
the workflow token's pull requests start no workflows), and Dependabot one
for newer actions. `main` is protected:
the `validate`, `linux-bundle / bundle` (both from 10) and `title` (11)
checks must pass, squash merges only; I (admin) may still push directly.

**The sandbox's clang-tidy is older than the flake's.** A green local
`rake check` does not prove CI green for the C checks: run `nix flake check`
before telling me a change is ready to push.

---

## 5. Readability rules

- Small methods with intention-revealing names; `App#tick` reads without
  opening other files.
- Value objects as plain classes (Spinel-friendly) for blocks, options,
  draw commands, state.
- No metaprogramming, monkey patching, globals, or `$1`-style magic.
- Regexes are named constants with a comment showing an example match.
- Comments explain *why*. Every file starts with a 1-3 line comment saying
  what it is responsible for.
- No bare `rescue`; rescue specific exceptions at the boundary (file IO,
  fonts, processes) and turn them into user-visible messages.
- Vocabulary: "block", "task", "line index", "draw command", "section",
  "anchor", "frame".

---

## 6. Testing

- Unit tests (Minitest, CRuby) for every behaviour, with fakes for the
  screen, fonts, tray and notifier; `test/unit/test_helper.rb` points
  `XDG_STATE_HOME` at a temp dir so tests never touch real state.
- `test/*.rb` are spin snapshot programs compiled by Spinel and compared with
  `spinel diff`.
- **The window is checked in Xvfb only** (`DISPLAY=:99`, `XAUTHORITY` unset),
  with the helper scripts in the session scratchpad. Never send input or
  screenshots to my real display.
- **D-Bus (tray) tests run on a private bus** (`dbus-run-session`) with a
  stand-in StatusNotifierWatcher; never on my session bus.
- Screenshots for the repo use made-up plans (`docs/example-week.md`), never
  my real runbooks: the repository is public.
- `docs/manual-testing.md` is the checklist for KDE, GNOME and Hyprland; add
  an item for every visible feature.

---

## 7. Nix

- `flake.nix`: `devShells.default` (Ruby tooling, Spinel, raylib, GLFW,
  systemdLibs, raygui, clang tools, cppcheck, yamllint, actionlint, shellcheck, desktop-file-utils, ...),
  `packages.default` (the binary, wrapped with fontconfig, xdg-utils and
  libnotify on PATH and Noto Emoji as `--emoji-font`; `meta` with MIT), and
  `checks.default` (`rake check` under a UTF-8 locale).
- Spinel is built from its release tarball pinned by hash, never `make deps`.
- Without Nix (the dev sandbox): `docs/development.md` (GLFW built shared and
  raylib against it with `USE_EXTERNAL_GLFW=ON`).

---

## 8. Documentation

Keep in step with every change:

- `README.md`: features, getting started, keys, Markdown table, config,
  command line, window rules, good to know, What Shipinel is not,
  contributing, how it works, license.
- `CONTRIBUTING.md`: the process (issues, gate, commit types, squash merge,
  releases).
- `docs/spinel-notes.md`, `docs/raylib-notes.md`, `docs/tray-notes.md`,
  `docs/exceptions.md`, `docs/manual-testing.md`, `docs/development.md`,
  `docs/config.example`, `docs/example-week.md` + `docs/screenshot.png`
  (still) + `docs/demo.gif` (recorded by `docs/demo/record.sh` in Xvfb, with
  the clock moved by `docs/demo/clock.c`; re-record when the look changes).

---

## 9. Working process

1. Agree on the feature first; anything near §1 "What it is not" or adding a
   dependency needs my explicit OK.
2. Work in small slices, each ending with `rake check` green, tests, docs,
   and (for visible changes) a check in Xvfb with a screenshot.
3. Commits: lowercase Conventional Commits (`feat(tray): ...`), committed
   with `--no-gpg-sign` in the sandbox (I re-sign on my host). Leave my
   untracked files (`resume_claude`) out.
4. Do not push unless I ask in that message; I usually push from my host.
5. Pull requests follow `.github/pull_request_template.md` and are
   squash-merged, so the title is the commit.
6. Releases: `rake bump[x.y.z]` (flake.nix, spin.toml,
   lib/shipinel/version.rb) in a `chore(release): x.y.z` PR, merge, run
   `20 · Release` (CONTRIBUTING.md). Its notes come from `rake
   release_notes` (commit subjects since the last tag; tested in
   test/unit/release_notes_test.rb).
7. If Spinel cannot compile something, do not hack around it: probe, record
   it in `docs/spinel-notes.md`, pick the simplest supported construct.

## Definition of done (every change)

- `rake check` (or `nix flake check`) passes with zero offenses.
- New behaviour has unit tests; visible behaviour was seen in Xvfb.
- README / docs say what changed for users.
- Idle CPU stays near zero (no new per-frame work for idle frames).
- Runs natively on Wayland; nothing user-visible depends on X11 alone
  without a Wayland fallback.
