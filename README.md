# Shipinel

"Ship it this week": a small, always-visible window that shows a Markdown
week plan and lets you tick its task checkboxes. Clicking a checkbox flips
`[ ]` ↔ `[x]` on that exact line of the file and saves it; edits made in any
other editor show up within about a second.

Written in Ruby, compiled to a native binary with
[Spinel](https://github.com/matz/spinel), drawn with raylib + raygui. Runs
natively on Wayland (and on X11).

## Build and run

With Nix (the supported way):

```sh
nix build              # → ./result/bin/shipinel
nix run . -- ~/notes/week.md
nix develop            # Ruby tooling, Spinel, raylib, clang tools
```

Without Nix, see [docs/development.md](docs/development.md) (Debian packages,
raylib from its 6.2 tag, Spinel from its release tarball), then:

```sh
spin build && build/bin/shipinel ~/notes/week.md
```

Quality gate: `bundle exec rake check` (or `nix flake check`).

## Command line

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

## Config

Optional: `~/.config/shipinel/config` (or `$XDG_CONFIG_HOME/shipinel/config`),
one `key=value` per line, `#` starts a comment line. Everything has a
default; a value that does not fit keeps it and is reported on stderr.

```ini
# The plan to open when shipinel is run without a path (~ is your home).
file=~/notes/week.md
# A daily notification with the number of open tasks, at this time (HH:MM);
# leave empty for none.
notify_daily=17:30
# A notification when ticking a box cannot be saved (default on).
notify_save_failed=on
# A tray icon (default off); with it, closing can hide the window there.
tray=on
close_to_tray=off
```

Yes/no settings take `on`/`off`, `yes`/`no`, `true`/`false` or `1`/`0`.

## Supported Markdown

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

### How saving works

A click re-reads the file first and changes the line only if it is still the
same task, in the state you saw; otherwise nothing is written and the page
shows what the file now holds. The new content is written to a hidden
temporary file next to yours and renamed over it, so editors never see a
half-written file. Permissions are kept, and a symlinked plan is written
through the link. If saving fails (e.g. a read-only directory), a red notice
says why, and the file is left as it was.

## Window rules

The window title is always exactly `shipinel`, so compositors can place it.
Shipinel does not position itself or stay on top on its own.

### KDE Plasma (KWin)

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

### Hyprland

```ini
windowrulev2 = float, title:^(shipinel)$
windowrulev2 = pin, title:^(shipinel)$
windowrulev2 = move 1460 40, title:^(shipinel)$
windowrulev2 = size 440 640, title:^(shipinel)$
```

`pin` keeps the floating window on every workspace. Newer Hyprland
versions merged `windowrulev2` into `windowrule`; the rules are the same.

### GNOME

GNOME has no window rules. Right-click the title bar and choose *Always on
Top* and *Always on Visible Workspace*, or use an extension that applies
rules by title (for example "Auto Move Windows" for the workspace part).

## Wayland

raylib uses GLFW, which picks its Wayland backend when `WAYLAND_DISPLAY` is
set. To confirm a running Shipinel is a native Wayland client:

```sh
WAYLAND_DEBUG=1 shipinel ~/notes/week.md 2>&1 | head
```

prints `wl_display` / `wl_registry` messages on a native Wayland window, and
nothing on X11. In KDE, the KWin debug console (`qdbus org.kde.KWin
/KWin showDebugConsole`) also lists it under *Wayland Windows*, not
*X11 Windows*.

To run it through XWayland instead (for example if your compositor
mishandles it):

```sh
env -u WAYLAND_DISPLAY shipinel ~/notes/week.md
```

## Keys

| Key | Does |
|---|---|
| `j` / `↓`, `k` / `↑` | Scroll a line down / up |
| Page Down / Page Up | Scroll a window down / up |
| Home / End | Go to the top / the end |
| `+` (or `=`), `-`, keypad `+` / `-` | Bigger / smaller text, with or without Ctrl; from 8 to 72 pixels |
| `0` | Back to the `--font-size` the window started with |
| `h` | Hide or show the progress header |

Keys repeat while held. Escape does nothing.

## Behaviour

- The window is drawn 60 times a second while you scroll, click or move
  the pointer over it (and half a second after), and otherwise only when
  the page changes or the window system asks for it. An idle window sleeps
  until input arrives, waking twice a second to check the file: it costs
  next to no CPU. The page is laid out again only when the file, the
  window size or the fonts change, and only what the window shows is
  drawn.
- The file is re-read about every 500 ms by comparing its content, which
  also catches editors that save by renaming.
- A strip pinned to the top of the window names the section you are in:
  the last heading scrolled to or past the top, or the file's name above
  the first one (cut with "…" when long). When the file has tasks, it also
  shows how many are checked ("12 of 40 tasks done · 30%") and a bar
  filled by that share, which turns green when every task is done. Tasks
  inside code fences do not count. `h` hides the strip.
- Each plan reopens where it was left: the same section (found by its
  heading, so edits above it do not move you), the same text size and
  header, and the window's size. On X11 the window's position comes back
  too; on Wayland only the compositor places windows, so use the window
  rules below. The state is a small text file per plan in
  `~/.local/state/shipinel/` (or `$XDG_STATE_HOME/shipinel/`), saved
  within half a second of a change; deleting it starts fresh.
- A page taller than the window gets a scrollbar on the right: the wheel
  scrolls, the thumb can be dragged, and a click on the track moves one
  window up or down. The scroll position survives reloads.
- Escape does nothing; only the window's close button quits.
- The window is resizable, and text re-wraps to its width.

## Project docs

- [docs/spinel-notes.md](docs/spinel-notes.md): what Spinel allows, with
  every rule this code follows because of it.
- [docs/raylib-notes.md](docs/raylib-notes.md): the raylib/raygui calls used,
  with signatures from the headers.
- [docs/exceptions.md](docs/exceptions.md): every place a check is relaxed,
  and why.
- [docs/manual-testing.md](docs/manual-testing.md): the checklist for KDE,
  GNOME and Hyprland.
