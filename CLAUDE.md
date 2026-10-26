# Project: Shipinel

Build **Shipinel** ("ship it this week"): a small, always-visible desktop window
that renders a Markdown week plan and lets me tick its task checkboxes. Written in
Ruby, compiled to a native binary with **Spinel** (https://github.com/matz/spinel),
UI drawn with **raylib + raygui** through Spinel's FFI.

Readability for humans is the top priority after correctness. Prefer boring,
obvious code over clever code.

---

## 1. What the app does (scope)

- `shipinel PATH/TO/file.md [--font PATH] [--font-size N]`
- Opens one window titled exactly `shipinel` (I match it in KWin / Hyprland
  window rules, so the title must never change).
- Renders the file read-only, except for task checkboxes:
  - Headings `#`, `##`, `###`
  - Task items `- [ ]` / `- [x]` / `- [X]` (also `*` and `+` bullets), including
    nested items by indentation
  - Plain bullet items
  - Paragraphs
  - Inline `**bold**` and `` `code` `` (simple styling is enough)
  - Horizontal rules `---`
  - Fenced code blocks shown as plain monospaced text. Lines inside fences are
    NEVER treated as tasks.
- Clicking a checkbox toggles `[ ]` <-> `[x]` on that exact source line and saves
  the file.
- External edits (vim, VS Code, Obsidian, etc.) are picked up automatically.
- Vertical scrolling with the mouse wheel when content is taller than the window.
- Light CPU usage when idle.

Out of scope: editing text, adding/removing tasks, tables, images, links,
multiple files, tray icon, config files.

---

## 2. Before writing any code: research step (mandatory)

Spinel is young (first release 2026.09.12) and supports only a subset of Ruby.
Do NOT rely on memory for it. First, clone or open the Spinel repo and read:

- `README.md`
- `docs/limitations.md`
- `docs/FFI.md`
- `docs/spin.md`
- `docs/inline-rbs.md` and `docs/rbs-extract.md`

Then write `docs/spinel-notes.md` in this project summarizing, in your own words,
every constraint that affects this app: unsupported Ruby features (e.g. no `eval`,
no `method_missing`, no dynamic `define_method`/`send`), FFI type mapping, how
`:ptr` values may and may not be stored (they cannot go into polymorphic arrays or
generic hashes), how carried `.c` files work in a `spin` package, which `File`
methods exist, and anything else relevant.

Also inspect the actual `raylib.h` and `raygui.h` headers you link against (in the
Nix store or vendored) and copy the exact signatures you use into
`docs/raylib-notes.md`. Never guess a raylib/raygui signature.

Show me both notes files and your implementation plan, then wait for my approval
before implementing.

---

## 3. Architecture

Keep a strict separation between pure logic (runs identically under CRuby and
Spinel, fully unit-tested) and the thin native UI layer.

    shipinel/
    ├── bin/shipinel.rb         # entry point: parse args, wire objects, run loop
    ├── lib/shipinel/
    │   ├── cli_options.rb      # argument parsing -> Options struct
    │   ├── markdown/
    │   │   ├── block.rb        # value objects: Heading, Task, Bullet, Paragraph, Rule, CodeLine
    │   │   ├── parser.rb       # String -> Array of blocks, each with its source line number
    │   │   └── inline.rb       # **bold** / `code` spans
    │   ├── task_toggler.rb     # toggles one source line, verifying it is still that task
    │   ├── document_file.rb    # read, change detection, atomic write
    │   ├── font_locator.rb     # --font, else `fc-match -f '%{file}' sans`
    │   ├── layout.rb           # blocks -> positioned draw commands (pure, testable)
    │   └── app.rb              # main loop orchestration
    ├── ext/
    │   ├── ui_shim.c           # small C adapter over raylib/raygui (scalar args only)
    │   └── ui_shim.h
    ├── lib/shipinel/ui.rb      # Spinel FFI declarations for ui_shim
    ├── sig/                    # RBS signatures where inline RBS is not enough
    ├── test/                   # unit tests (CRuby) + spin snapshot tests
    ├── flake.nix               # devShell + package
    └── Rakefile                # dev tasks only (runs under CRuby, never compiled)

### Key design rules

- **Parse by line, keep line numbers.** Every block remembers its source line
  index. The UI builds from blocks; a click maps to a line number, never to
  "the n-th checkbox in rendered output".
- **Safe toggling.** `TaskToggler` re-reads the file, verifies the target line
  still matches the task regex and the expected state, toggles only the
  `[ ]`/`[x]` characters, and writes atomically. If the line changed, it does
  nothing and the next reload shows the current state.
- **Atomic writes.** Write to a temp file in the same directory, then call libc
  `rename(2)` through FFI. Preserve the original trailing newline and line
  endings.
- **Change detection.** Poll by re-reading the file every ~500 ms and comparing
  content (files are tiny; this survives editors that save by rename). No
  inotify. Keep scroll position across reloads. A missing/unreadable file shows a
  friendly message in the window instead of crashing, and recovers when the file
  reappears.
- **Native layer is dumb.** `ui_shim.c` exposes only functions with scalar /
  string arguments (raylib passes `Color`, `Vector2`, `Rectangle`, `Font` by
  value, which Spinel FFI cannot do). It holds the loaded fonts as static state.
  No app logic in C. Prefer a carried `.c` file over `ffi_source`.
- **Fonts and accents.** The default raylib font lacks accented characters. Load
  a TTF with `LoadFontEx` including at least ASCII + Latin-1 Supplement +
  Latin Extended-A codepoints, so Portuguese text ("Reunião", "ação") renders
  correctly. Add a test fixture with accented text.
- **Idle behavior.** Use `SetTargetFPS(10)`. Do NOT use `EnableEventWaiting()`
  (it would block file polling). Use `FLAG_WINDOW_RESIZABLE`; positioning and
  always-on-top are handled by the compositor, not by the app.
- **Wayland.** Must work natively on Wayland under KDE Plasma, GNOME and
  Hyprland. Document in the README how to verify the linked raylib/GLFW was
  built with Wayland support, and how to fall back to XWayland.
- **Theme.** One dark theme defined as named constants in one place; no magic
  color numbers scattered around.

---

## 4. Code quality: conventions, guards and static analysis

All of the following must pass with zero offenses before a phase is considered
done. Wire them into `rake check` (and a `nix flake check` equivalent).

### Ruby style and correctness
- **RuboCop** with `rubocop-performance`, `rubocop-rake`, `rubocop-minitest`,
  and **rubocop_spinel** (https://github.com/gurgeous/rubocop_spinel) to flag
  Ruby that Spinel cannot compile. `NewCops: enable`.
- `# frozen_string_literal: true` in every file.
- No disabling cops inline unless the comment explains why; list every such case
  in `docs/exceptions.md`.

### Complexity and design metrics (enforced, not advisory)
- RuboCop Metrics:
  - `Metrics/MethodLength`: Max 10
  - `Metrics/AbcSize`: Max 15
  - `Metrics/CyclomaticComplexity`: Max 6
  - `Metrics/PerceivedComplexity`: Max 7
  - `Metrics/ClassLength`: Max 100
  - `Metrics/ModuleLength`: Max 100
  - `Metrics/ParameterLists`: Max 4
  - `Metrics/BlockNesting`: Max 2
- **Flog**: no method above 20; report the total and the 5 worst methods.
- **Flay**: no duplication above mass 25.
- **Reek**: default smells enabled; justify any suppression in `.reek.yml`.
- **RubyCritic**: generate a report and keep every file at grade A or B.

### Types
- Use Spinel's inline RBS comments (`#: (Integer) -> String`, `attr_reader :x #: String`)
  on every public method, plus files under `sig/` where needed.
- Type-check with **Steep** under CRuby.
- Compile with `spinel --rbs sig` and `--warn-widen`; treat any widen warning
  as an error unless documented in `docs/exceptions.md`.

### Native code (ext/)
- Compile with `-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Werror`.
- **clang-tidy** (bugprone, readability, performance checks) and **cppcheck**
  with zero findings.
- **clang-format** with a checked-in `.clang-format`.

### Spinel-specific checks
- `spinel diff` on the CLI entry points and test programs: output must be
  `same` between CRuby and Spinel for all non-UI code paths.
- The full app must build with `spin build` with no warnings.

---

## 5. Readability rules

- Small methods with intention-revealing names; a reader should understand
  `App#tick` without opening other files.
- Value objects via `Struct.new(..., keyword_init: true)` (or plain classes if
  Spinel requires) for blocks, options and draw commands.
- No metaprogramming, no monkey patching, no global variables, no `$1`-style
  magic outside the parser (name your captures or assign them immediately).
- Regexes are named constants with a comment showing an example match.
- Comments explain *why*, not *what*. Every file starts with a 1-3 line comment
  saying what it is responsible for.
- Errors: no bare `rescue`. Rescue specific exceptions at the boundary
  (file IO, font loading) and turn them into user-visible messages.
- Consistent vocabulary: "block", "task", "line index", "draw command". Use it
  everywhere.

---

## 6. Testing

- Unit tests with **Minitest** under CRuby for: parser (including fences,
  nesting, mixed bullets, CRLF files, empty file, accented text), inline spans,
  task toggling (including "line changed underneath" and "file deleted"), atomic
  write (original preserved on failure), change detection, CLI options, layout.
- `spin test` snapshot tests for the pure modules compiled with Spinel.
- **SimpleCov** under CRuby: minimum 95% line coverage for `lib/` excluding
  `ui.rb`.
- A manual test checklist in `docs/manual-testing.md` for the UI on KDE,
  GNOME and Hyprland.

---

## 7. Nix

- `flake.nix` with:
  - `devShells.default`: Ruby (CRuby for tooling), gcc, clang-tools, cppcheck,
    raylib, pkg-config, fontconfig, and Spinel.
  - `packages.default`: builds the `shipinel` binary.
- Build Spinel from a **release tarball** pinned by hash (release archives
  vendor the parsers and build with plain `make`, no network), not from
  `make deps`.
- If raygui is not in nixpkgs, vendor `raygui.h` from a pinned release tag and
  record the version and license in `ext/VENDORED.md`.

---

## 8. Documentation

`README.md` must include: what it is, build and run, the CLI, the supported
Markdown subset, and copy-paste window rule examples for:
- KDE (KWin rule matching title `shipinel`: position, size, keep above/below,
  all desktops, skip taskbar)
- Hyprland (`windowrulev2 = float, pin, move, size` on `title:^(shipinel)$`)
- GNOME (no native rules: "Always on Top" from the window menu, or an extension)

---

## 9. Working process

1. Research step (section 2), then present the plan and wait.
2. Implement in phases, each ending with `rake check` fully green and a short
   summary of what changed and the current Flog/RubyCritic numbers:
   1. Project skeleton, tooling, `rake check`, flake devShell
   2. Markdown parser + inline spans + tests
   3. Task toggling + document file + tests
   4. C shim + FFI module + a window that renders static text with accents
   5. Layout + full rendering + click-to-toggle + scrolling
   6. Polling reload, error states, README, manual test checklist, Nix package
3. If Spinel cannot compile something, do not work around it with hacks: write a
   minimal reproducer, note it in `docs/spinel-notes.md`, and choose the simplest
   supported construct instead.
4. Never weaken a lint/metric threshold to make a check pass; refactor instead.
   If you truly believe a threshold is wrong, stop and ask me.

## Definition of done

- `nix build` produces a working `shipinel` binary.
- `rake check` passes with zero offenses across all tools listed above.
- Toggling a checkbox updates the file on disk, and an external edit shows up
  within about one second.
- Accented Portuguese text renders correctly.
- Runs natively on Wayland under KDE Plasma.
