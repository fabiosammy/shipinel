<h1 align="center">Shipinel</h1>

<p align="center">
  <i>Ship it this week.</i> A small, always-visible window that shows your
  Markdown week plan<br />and lets you tick its tasks, so the week's work stays
  in view while you do it.
</p>

<p align="center">
  <a href="https://github.com/fabiosammy/shipinel/issues">Report a bug or suggest an idea</a>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="440" alt="Shipinel showing an example week: 4 of 12 tasks done, a tick on the bar where Wednesday afternoon is, and the tasks of Goal 1" />
</p>

## Features

- **Your plan, as you wrote it.** A Markdown file you keep in your editor (or
  that an assistant updates). Shipinel shows it and lets you tick its
  checkboxes: a click flips `[ ]` ↔ `[x]` on that exact line and saves the
  file. Edits made anywhere else show up within a second.
- **Progress against the week.** "12 of 40 tasks done · 30%", a bar filled by
  that share, and a tick where the work week is. The bar turns amber when you
  are more than a day behind, and green when everything is done.
- **Where you are.** The header names the section you are in, with its own
  count ("Goal 1 — Billing CSV export · 3 of 7"), and the plan reopens where
  you left it, at the same size, even after it was edited above you.
- **Keyboard**: `j`/`k`, the arrows, Page Up/Down and Home/End scroll; `+`,
  `-` and `0` zoom; `h` hides the header.
- **Notifications**: a daily nudge with the number of tasks still open, and a
  warning when a tick could not be saved.
- **Tray icon**: the progress as a ring and in its tooltip; a click shows or
  hides the window, and closing can hide it there instead of quitting.
- **Light on the machine.** An idle window sleeps until input arrives and
  costs next to no CPU.
- Native on **Wayland** (KDE Plasma, Hyprland, GNOME) and on X11.

## Getting started

1. Build it with [Nix](https://nixos.org):

   ```sh
   nix build                       # → ./result/bin/shipinel
   ./result/bin/shipinel docs/example-week.md
   ```

   `nix run github:fabiosammy/shipinel -- ~/notes/week.md` runs it without
   cloning. Without Nix, see [Development setup](#development-setup).
2. Point it at your plan: `shipinel ~/notes/week.md`, or set `file=` in the
   [config](#config) and run `shipinel` alone.
3. Keep it in view with a [window rule](#window-rules): position, size, on top
   and on every desktop.
4. Optionally, turn on the [tray icon and notifications](#config).

### Keys

| Key | Does |
|---|---|
| `j` / `↓`, `k` / `↑` | Scroll a line down / up |
| Page Down / Page Up | Scroll a window down / up |
| Home / End | Go to the top / the end |
| `+` (or `=`), `-`, keypad `+` / `-` | Bigger / smaller text, with or without Ctrl; from 8 to 72 pixels |
| `0` | Back to the `--font-size` the window started with |
| `h` | Hide or show the progress header |

Keys repeat while held. Escape does nothing; only the window's close button
quits (or hides it in the tray, see `close_to_tray`).

### Supported Markdown

| Markdown | Shown as |
|---|---|
| `#`, `##`, `###` (up to `######`) headings, optional closing `#`s | Bold, sized by level |
| `- [ ] task`, `- [x] task`, `- [X] task`, also with `*` or `+` | A checkbox you can click; done tasks are dimmed |
| `- item`, `* item`, `+ item` | A bullet |
| `1. item`, `2) item` | A numbered item, with its own number; `1. [ ] task` is a task |
| Indented items (2 or 4 spaces, or tabs) | Nested, indented by depth |
| Consecutive text lines | One wrapped paragraph |
| `**bold**`, `` `code` `` inside any text | Bold; monospace on a dark background |
| `~~text~~` | Struck through, the line in the text's own color |
| `*italic*`, `_italic_` | Italic. The markers must touch the text (`2 * 3 * 4` stays as written), and `_` only counts at word edges, so `snake_case` and `workspace_id` are left alone |
| `> quoted` lines | Indented, italic and dimmed, with a bar on the left; consecutive lines join, a lone `>` starts a new quote. Markdown inside a quote other than inline styles is shown as written |
| `[text](url)`, `<https://…>`, bare `https://…` URLs | An underlined link; the pointer turns into a hand over it, and a click opens it with `xdg-open` (a relative link opens the file next to the plan) |
| `\| a \| b \|` tables, with a `\|---\|---\|` row under the header | Columns sized to their content and shrunk to fit the window; text wraps inside each cell; header rows bold |
| Arrows, symbols, emoji (`→ ✓ 🤖 ⏳`) | Drawn from the text font when it has them, otherwise from the emoji font |
| `---`, `***`, `___` | A horizontal rule |
| ```` ``` ```` or `~~~` fenced blocks | Monospaced lines; a `- [ ]` inside a fence is never a task |

Anything else (images, nested quotes, lists inside quotes, tables without
leading and trailing `|`) is shown as plain text. Windows line endings and a
missing final newline are kept exactly when a checkbox is toggled.

### Config

Optional: `~/.config/shipinel/config` (or `$XDG_CONFIG_HOME/shipinel/config`),
one `key=value` per line, `#` starts a comment line. Everything has a
default; a value that does not fit keeps it and is reported on stderr.

| Setting | Default | Does |
|---|---|---|
| `file` | none | The plan opened when `shipinel` runs without a path (`~` is your home). A path on the command line wins. |
| `notify_daily` | empty (off) | `HH:MM`: once a day from that time, a notification with how many tasks are still open (nothing when all are done; also sent when the window opens later that day). |
| `notify_save_failed` | `on` | A notification when ticking a box cannot be saved. |
| `tray` | `off` | The tray icon. |
| `close_to_tray` | `off` | With the tray icon, the close button hides the window there instead of quitting. |

Yes/no settings take `on`/`off`, `yes`/`no`, `true`/`false` or `1`/`0`.
[docs/config.example](docs/config.example) is a complete file with every
setting explained:

```sh
install -D -m 644 docs/config.example ~/.config/shipinel/config
```

### Command line

```
shipinel [PATH.md] [--font PATH] [--font-size N] [--emoji-font PATH]
```

| Option | Meaning |
|---|---|
| `PATH.md` | The file to show. If it does not exist yet, the window says so and shows it as soon as it appears. Without it, the config's `file` is opened. |
| `--font PATH` | A TTF/OTF font for the text (also used for bold and italic). Default: what `fc-match sans` returns, with `fc-match sans:bold` for bold and `fc-match sans:italic` for italic; if no italic face is installed, fontconfig returns the upright one and italics look upright. Code always uses `fc-match monospace`. |
| `--font-size N` | Body text size in pixels, 8 to 72. Default 20. Headings are larger, code slightly smaller. |
| `--emoji-font PATH` | A **monochrome** TTF/OTF for emoji and other symbols the text font lacks. Default: `fc-match 'emoji:color=false'`; the Nix package passes Noto Emoji. Colour emoji fonts (Noto Color Emoji) are bitmaps raylib cannot draw. |

Wrong arguments print a usage message and exit with status 2.

### Window rules

The window title is always exactly `shipinel`, so compositors can place it.
Shipinel does not position itself or stay on top on its own.

#### KDE Plasma (KWin)

System Settings → Window Management → Window Rules → Add New…, then:
Window title *Exactly Match* `shipinel`, and add Position, Size, Keep above
(*Force*), Virtual Desktop (*Force*, all desktops) and Skip taskbar
(*Force*).

Or as a file: if you have **no** KWin rules yet, this is a complete
`~/.config/kwinrulesrc` (otherwise add the `[shipinel]` group, append
`shipinel` to `rules=` and increase `count=`):

```ini
[General]
count=1
rules=shipinel

[shipinel]
Description=shipinel week plan
title=shipinel
titlematch=1
position=1460,40
positionrule=3
size=440,640
sizerule=3
above=true
aboverule=2
desktops=
desktopsrule=2
skiptaskbar=true
skiptaskbarrule=2
```

`titlematch=1` is an exact match; rule `2` is *Force* and `3` is *Apply
initially* (KWin `rules.h`). An empty `desktops` list forced means all
desktops. Reload with `qdbus org.kde.KWin /KWin reconfigure` (`qdbus6` on
some distributions), or log out and in.

#### Hyprland

```ini
windowrulev2 = float, title:^(shipinel)$
windowrulev2 = pin, title:^(shipinel)$
windowrulev2 = move 1460 40, title:^(shipinel)$
windowrulev2 = size 440 640, title:^(shipinel)$
```

`pin` keeps the floating window on every workspace. Newer Hyprland
versions merged `windowrulev2` into `windowrule`; the rules are the same.

#### GNOME

GNOME has no window rules. Right-click the title bar and choose *Always on
Top* and *Always on Visible Workspace*, or use an extension that applies
rules by title (for example "Auto Move Windows" for the workspace part).

### Good to know

- **Saving.** A click re-reads the file first and changes the line only if
  it is still the same task, in the state you saw; otherwise nothing is
  written and the page shows what the file now holds. The new content goes
  to a hidden temporary file next to yours and is renamed over it, so
  editors never see a half-written file. Permissions are kept, and a
  symlinked plan is written through the link. If saving fails (a read-only
  directory, say), a red notice says why and the file is left as it was.
- **Reopening where you left.** Each plan's section (found by its heading),
  text size, header and window size are kept in a small file per plan in
  `~/.local/state/shipinel/` (or `$XDG_STATE_HOME`), saved within half a
  second of a change; deleting it starts fresh. On X11 the window's position
  comes back too; on Wayland only the compositor places windows, so use a
  window rule.
- **The pace** assumes the tasks are spread evenly from Monday 00:00 to
  Friday 24:00; at the weekend the week is over. More than a workday's share
  behind (20% of the tasks) turns the bar amber. Tasks inside code fences
  never count.
- **The tray icon** shows on KDE Plasma as is; Hyprland needs a bar with a
  tray (waybar's `tray` module), GNOME the AppIndicator extension. Without a
  tray, Shipinel says so on stderr and closing quits as usual.
- **Notifications** go through `notify-send` (libnotify), which the Nix package
  brings.
- **Idle cost.** The window is drawn 60 times a second only while you scroll,
  click or point at it; otherwise it sleeps until input arrives, waking twice
  a second to check the file (by content, so editors that save by renaming
  are caught too).
- **Wayland or X11.** raylib uses GLFW, which picks its Wayland backend
  when `WAYLAND_DISPLAY` is set. `WAYLAND_DEBUG=1 shipinel 2>&1 | head`
  prints `wl_display` / `wl_registry` messages on a native Wayland window and
  nothing on X11; KDE's debug console (`qdbus org.kde.KWin /KWin
  showDebugConsole`) also lists it under *Wayland Windows*. To run it through
  XWayland instead: `env -u WAYLAND_DISPLAY shipinel`.

## What Shipinel is not

Shipinel stays small on purpose: it keeps one week's work in view so you
deliver it. These are left out by design, not by lack of time:

- **Not an editor.** No typing, no adding, moving or deleting tasks: your
  editor (or an assistant) writes the plan; Shipinel only flips checkboxes.
  Two writers on one file is how plans get lost.
- **Not a filter or a task manager.** It shows the whole plan as you wrote it:
  no views, tags, priorities, assignees or due-date engine.
- **Not a timer.** No pomodoros, time tracking or focus sessions; they compete
  for attention instead of directing it.
- **No history, stats or streaks.** It is about this week, not about the
  past ones.
- **Not a service.** One local file: no accounts, no sync, no network, except
  the links you click and the notifications your desktop shows.

Ideas that fit these lines are welcome; ideas that cross them belong in
another tool.

## Contributing

Bug reports, ideas and pull requests are welcome. Please open an
[issue](https://github.com/fabiosammy/shipinel/issues) first for bigger
changes, and keep [What Shipinel is not](#what-shipinel-is-not) in mind.

### Development setup

With Nix:

```sh
nix develop               # Ruby tooling, Spinel, raylib, GLFW, libsystemd, clang tools
bundle exec rake check    # every gate below; also `nix flake check`
spin build                # → build/bin/shipinel
```

Without Nix (Debian 12): [docs/development.md](docs/development.md) has the
packages, GLFW and raylib 6.2 built from source, and Spinel from its release
tarball.

`rake check` must pass with zero offenses before anything is merged:

- **Ruby**: RuboCop (with rubocop_spinel), Reek, Flog (≤ 20 per method),
  Flay, RubyCritic (every file A or B), Steep with inline RBS, Minitest with
  SimpleCov (≥ 95% of lines).
- **C** (`ext/`): `-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Werror`,
  clang-tidy, cppcheck, clang-format.
- **Spinel**: the app and the snapshot programs compile with every widening
  warning treated as an error, and `spinel diff` prints the same under
  CRuby and Spinel.

Thresholds are never relaxed; the few narrow exceptions are listed, with
their reasons, in [docs/exceptions.md](docs/exceptions.md). The window itself
is checked by hand: [docs/manual-testing.md](docs/manual-testing.md).

### How it works

Shipinel is Ruby compiled to a native binary by
[Spinel](https://github.com/matz/spinel), which takes a subset of Ruby
([docs/spinel-notes.md](docs/spinel-notes.md) lists what this code follows
because of it). Everything that decides something is plain Ruby, unit-tested
under CRuby; the native side is a thin C shim that takes only numbers and
strings.

| Part | Role |
|---|---|
| `bin/shipinel.rb` | Entry point: command line, config, fonts, then `App` |
| `lib/shipinel/markdown/` | The parser: lines to blocks (each with its source line), inline spans |
| `lib/shipinel/layout.rb`, `flow.rb`, `line_wrap.rb`, `*_layout.rb` | Blocks to positioned draw commands for a window width |
| `lib/shipinel/page.rb`, `typesetter.rb`, `header.rb`, `painter.rb` | One frame: the cached layout, the header and scrollbar, drawing and clicks |
| `lib/shipinel/app.rb`, `session.rb`, `desktop.rb` | The loop, the file poll, the saved state, notifications and the tray |
| `lib/shipinel/task_toggler.rb`, `document_file.rb` | Flipping one checkbox safely and writing the file atomically |
| `lib/shipinel/ui.rb` | Spinel FFI declarations for the C side |
| `ext/ui_shim.c` | The window over raylib, raygui and GLFW: drawing, input, frame pacing |
| `ext/tray.c` | The tray icon: StatusNotifierItem and dbusmenu over sd-bus |

More detail: [docs/raylib-notes.md](docs/raylib-notes.md) (every raylib,
raygui and GLFW call, with signatures from the headers) and
[docs/tray-notes.md](docs/tray-notes.md) (the tray's D-Bus interfaces).

The screenshot above is of [docs/example-week.md](docs/example-week.md), a
made-up plan.
