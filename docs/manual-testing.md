# Manual testing

What the automated gate cannot check: a real compositor, real input, real
fonts. Run this on each desktop before calling a change done. Record the
date, desktop and result in the table at the end.

## Setup

```sh
nix build
cp test/fixtures/semana.md /tmp/semana.md
./result/bin/shipinel /tmp/semana.md
```

## Checklist (every desktop)

1. **Title.** The window title is exactly `shipinel` (title bar, task
   switcher, or `hyprctl clients`).
2. **Native Wayland.** `WAYLAND_DEBUG=1 ./result/bin/shipinel /tmp/semana.md
   2>&1 | grep -m1 wl_display` prints a line. (Skip on X11 sessions.)
3. **Accents.** "Semana 45", "reuniões", "ação", "Terça-feira", "pão" render
   with their accents, no boxes or question marks.
4. **Rendering.** Headings bold and larger; "**entregar**" bold; "`shipinel`"
   monospace on a dark background; nested tasks indented; the two checked
   tasks dimmed; a rule between the days; the fenced line shown as code,
   without a checkbox.
5. **Toggle.** Click the box of "Reunião de planejamento". It shows checked
   within a frame, and `git diff --no-index test/fixtures/semana.md
   /tmp/semana.md` shows only `[ ]` → `[x]` on that line, line endings
   (CRLF) unchanged. Click again: the file matches the fixture again.
6. **Edited underneath.** In an editor, change "Reunião de planejamento" to
   "Reunião cancelada" and save, then (within half a second) click its box:
   the file keeps your edit, nothing else changes.
7. **External edits.** Save the file from `vim` (`:w`), from VS Code, and
   from Obsidian (if used): each change appears within about a second.
8. **Missing file.** `rm /tmp/semana.md`: a red "does not exist" notice
   appears. `cp test/fixtures/semana.md /tmp/semana.md`: the plan comes back
   by itself.
9. **Read-only directory.** `mkdir /tmp/ro && cp test/fixtures/semana.md
   /tmp/ro/ && chmod 555 /tmp/ro`, run shipinel on `/tmp/ro/semana.md` and
   click a box: a red "Cannot save" notice appears and the file is
   unchanged. Clean up with `chmod 755 /tmp/ro && rm -r /tmp/ro`.
10. **Scrolling.** Make the window short (or use a long file): a scrollbar
    appears on the right. The wheel scrolls and stops at the top and at the
    end; dragging the thumb moves the page; a click on the track above or
    below the thumb moves one window up or down; the position stays when
    the file is edited externally. A file that fits shows no scrollbar.
11. **Resize.** Make the window narrow: the paragraph re-wraps; the window
    cannot be made smaller than 200 × 120.
12. **Keys.** Escape does not close the window; the close button does.
    `j`/`k` and the arrows scroll a line, Page Up/Down a window, Home/End
    go to either end; holding a key repeats it. `+`/`-` (also with Ctrl,
    and on the keypad) change the text size and `0` resets it; `h` hides
    and shows the progress header. On a pt-BR (ABNT2) keyboard, `+` is the
    key right of `-`. `~~text~~` shows struck through.
13. **Idle CPU.** `top -p $(pgrep -f result/bin/shipinel)` shows a few
    percent at most while nothing changes, on a long file too. Scrolling
    and dragging the scrollbar move smoothly (60 FPS), and the CPU drops
    back about half a second after the pointer stops; `top` then shows
    0.0–0.1 %. A quick click (and a touchpad tap) on a checkbox of an idle
    window still toggles it, an external edit made while idle still shows
    within about a second, and closing the window quits at once. On X11
    without a compositor, a window uncovered by another one is redrawn.
14. **Fonts.** `--font /nonexistent.ttf` exits with
    `--font /nonexistent.ttf: no such file`. `--font` with a real TTF and
    `--font-size 28` changes the text accordingly.
15. **Window rule.** With the rule from the README, the window opens at the
    configured position and size, stays above other windows and on every
    desktop/workspace, and is not in the task bar (where the desktop
    supports that).
16. **Progress.** A file with tasks shows "N of M tasks done · P%" and a
    bar at the top that stays put while scrolling; ticking a box updates
    both at once, and the bar turns green when every task is checked.
    Checkboxes scrolled under the strip cannot be clicked. A file without
    tasks shows only the section line.
17. **Sections and memory.** Scroll into a section: the strip names it
    (the file name above the first heading). Zoom: you stay in that
    section. Close and reopen: same section, size and header state, and
    the same window size (on X11 also the position). Add lines above that
    section while it is closed: it still reopens there.
18. **Config.** With `file=` in `~/.config/shipinel/config`, `shipinel`
    with no path opens that plan; a path on the command line wins. Without
    either, the usage message names the config file. A bad value (`tray=maybe`)
    prints one line on stderr and the window still opens.
19. **Notifications.** With `notify_daily` a minute in the past, the
    desktop shows "N tasks still open" once; closing and reopening the
    window the same day shows nothing new. With the plan in a read-only
    folder, ticking a box shows "Shipinel could not save" with the reason.
    Without `notify-send` on PATH, each one prints a line on stderr instead.
20. **Tray.** With `tray=on`: on KDE the icon appears with a ring and a
    tooltip "N of M tasks done · P%" that follow the ticks. A click hides
    the window, another brings it back where the window rules put it. The
    menu's Quit ends Shipinel. With `close_to_tray=on`, the close button
    hides the window and the icon stays. On Hyprland with waybar's tray the
    same; on GNOME without the AppIndicator extension, stderr says there is
    no tray and the close button quits.

## Per desktop

- **KDE Plasma (Wayland):** all of the above; item 15 with the KWin rule.
  Also try the XWayland fallback: `env -u WAYLAND_DISPLAY ./result/bin/shipinel
  /tmp/semana.md` (item 2 then prints nothing, everything else still works).
- **GNOME (Wayland):** item 15 by right-clicking the title bar → *Always on
  Top* and *Always on Visible Workspace*. Check that the window has a title
  bar (GLFW uses libdecor on GNOME).
- **Hyprland:** item 15 with the `windowrulev2` lines; the window floats and
  is pinned on every workspace.

## Results

| Date | Desktop | Session | Result | Notes |
|---|---|---|---|---|
| 2026-11-07 | Xvfb in the dev sandbox (no compositor) | X11, software GL | Items 1, 3, 4, 5 (CRLF file byte-identical after two toggles), 7 (save by rename), 8, 10 (wheel and a click after scrolling) pass | Driven with XTest inside Xvfb; not a real desktop |
| 2026-11-07 | NixOS host, `nix build` result | Wayland | Item 2 passes (`wl_display#1.get_registry`: native Wayland client) | Remaining items not yet run |
