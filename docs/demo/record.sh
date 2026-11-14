#!/usr/bin/env bash
# Records the README's animated screenshots: Shipinel showing
# docs/example-week.md on Wednesday 2026-11-11 at 15:30 (the clock is moved
# by docs/demo/clock.c) while a scripted user goes through one scene:
#   overview (docs/demo.gif)      a task ticked, an edit from another editor
#                                 marked, the page scrolled, `u` undoing the
#                                 tick, `h` hiding and showing the header
#   find (docs/demo-find.gif)     Ctrl+F, typing, Enter / Shift+Enter, Escape
#   keys (docs/demo-keys.gif)     Tab and Space ticking a task, the outline
#                                 (g) jumping to a section, the help (?)
#   select (docs/demo-select.gif) dragging over text, Ctrl+A
# Run them again when the window's look changes.
#
# Usage: docs/demo/record.sh PATH/TO/shipinel OUT.gif [SCENE]   (overview)
# Needs Xvfb, xdotool, ffmpeg with x11grab (Debian's ffmpeg, nixpkgs'
# ffmpeg-full), a C compiler and Mesa's software OpenGL driver. The pointer
# is not recorded: Xvfb only has its bare "X" cursor. The fonts are whatever fontconfig finds (the README's images use
# Liberation Sans; set FONTCONFIG_FILE to choose). It starts its own display
# on a number nobody uses, and never touches a real one.
set -euo pipefail

shipinel=$(realpath "$1")
out=$(realpath -m "$2")
scene=${3:-overview}
here=$(dirname "$(realpath "$0")")
work=$(mktemp -d)
plan=$work/example-week.md
size=440x640

# Clicks at x y, holding the button for 100 ms (raylib can miss a press
# and release that fall between two of its input polls). The window is at
# the screen's top-left corner, so these are window coordinates too.
click_at() {
  xdotool mousemove "$1" "$2" mousedown 1
  sleep 0.1
  xdotool mouseup 1
}

# Presses a key for 100 ms, as `click` does.
press() {
  xdotool keydown "$1"
  sleep 0.1
  xdotool keyup "$1"
}

# Presses a key with Control or Shift held (`ctrl+f`, `shift+Return`).
chord() {
  xdotool keydown "${1%%+*}"
  press "${1#*+}"
  xdotool keyup "${1%%+*}"
}

# Types text a character at a time, as a person would.
type_slowly() {
  xdotool type --delay 180 "$1"
}

# Drags from x1 y1 to x2 y2 in steps, the button held.
drag() {
  xdotool mousemove "$1" "$2" mousedown 1
  for step in 1 2 3 4 5 6 7 8; do
    xdotool mousemove $(($1 + ($3 - $1) * step / 8)) $(($2 + ($4 - $2) * step / 8))
    sleep 0.08
  done
  xdotool mouseup 1
}

# A task ticked, an edit from another editor, the page scrolled, the tick
# undone, the header hidden and shown.
overview() {
  # Tick "Rehearse the export demo": the counts and the bar move.
  click_at 24 304
  sleep 1.6

  # Another editor changes a line: it gets the change mark.
  sed -i 's/^- \[ \] Book a room for the retro$/- [ ] Book a room for the retro and the demo/' "$plan"
  sleep 2.2

  # Down to the overdue date and the task waiting on finance, and back.
  for _ in 1 2 3 4 5; do
    press j
    sleep 0.25
  done
  sleep 2
  press Home
  sleep 1.2

  # u: the tick is undone.
  press u
  sleep 2.2

  # h hides the header, and shows it again.
  press h
  sleep 1.4
  press h
  sleep 1.5
}

# The find bar: every match highlighted, Enter to the next one (the page
# scrolls to it), Shift+Enter back, Escape closes it.
find_scene() {
  chord ctrl+f
  sleep 0.6
  type_slowly "export"
  sleep 1.4
  press Return
  sleep 1.4
  press Return
  sleep 1.4
  chord shift+Return
  sleep 1.4
  press Escape
  sleep 1.2
}

# Ticking from the keyboard, the outline and the help.
keys_scene() {
  press Tab
  sleep 0.8
  press Tab
  sleep 0.8
  press space
  sleep 1.4
  press Escape
  sleep 0.8
  press g
  sleep 1.2
  for _ in 1 2 3; do
    press Down
    sleep 0.5
  done
  press Return
  sleep 1.6
  xdotool type "?"
  sleep 2.4
  press Escape
  sleep 1.0
}

# Selecting: a drag over the paragraph, then Ctrl+A, then a click away.
select_scene() {
  drag 60 156 330 210
  sleep 1.8
  chord ctrl+a
  sleep 1.8
  click_at 300 600
  sleep 1.0
}

# Ends a process we started (`signal` and pid) and waits for it, unless it
# already ended.
end_process() {
  if [ -n "$2" ] && [ -d "/proc/$2" ]; then
    kill "-$1" "$2"
    tail --pid="$2" -f /dev/null
  fi
}

# Stops the recording, the app and the display, whatever happened.
stop() {
  end_process INT "${recorder:-}"
  end_process TERM "${app:-}"
  end_process TERM "$xvfb"
}

cc -shared -fPIC -o "$work/clock.so" "$here/clock.c" -ldl
cp "$here/../example-week.md" "$plan"

# A display number nobody uses: no socket and no lock (test/window/run.sh
# says why Xvfb must not pick it itself).
number=90
while [ -e "/tmp/.X11-unix/X$number" ] || [ -e "/tmp/.X$number-lock" ]; do
  number=$((number + 1))
done
Xvfb ":$number" -displayfd 3 -screen 0 1024x768x24 -nolisten tcp 3> "$work/display" &
xvfb=$!
trap stop EXIT
for _ in $(seq 100); do
  if [ -s "$work/display" ]; then
    break
  fi
  sleep 0.1
done
export DISPLAY=":$number"
export XDG_STATE_HOME=$work/state XDG_CONFIG_HOME=$work/config
unset XAUTHORITY WAYLAND_DISPLAY

# Saved earlier the same day, at the screen's top-left corner (X11 keeps
# the position), so it opens at the top of the plan where ffmpeg records.
state=$XDG_STATE_HOME/shipinel/$(printf '%s' "$plan" | tr / %)
mkdir -p "$(dirname "$state")"
printf 'section=\nwithin=0.0\noffset=0.0\nsize=20\nheader=1\nwidth=440\nheight=640\nx=0\ny=0\nnudged=\nday=2026-11-11\n' \
  > "$state"

shift_seconds=$(($(date -d "2026-11-11 15:30" +%s) - $(date +%s)))
CLOCK_SHIFT=$shift_seconds LD_PRELOAD=$work/clock.so "$shipinel" "$plan" &
app=$!
window=$(timeout 30 xdotool search --sync --name '^shipinel$' | head -n 1)
sleep 2
xdotool windowfocus --sync "$window"

ffmpeg -loglevel error -f x11grab -framerate 15 -video_size "$size" -draw_mouse 0 -i "$DISPLAY+0,0" \
  -c:v libx264rgb -crf 0 -preset ultrafast "$work/demo.mkv" < /dev/null &
recorder=$!
sleep 1.5
if [ ! -d "/proc/$recorder" ]; then
  echo "FAIL: ffmpeg stopped at once (does it have x11grab?)"
  exit 1
fi

case $scene in
  overview) overview ;;
  find) find_scene ;;
  keys) keys_scene ;;
  select) select_scene ;;
  *) echo "unknown scene: $scene (overview, find, keys, select)"; exit 1 ;;
esac

end_process INT "$recorder"
recorder=

# Few colors, so a palette made from the recording keeps the GIF small
# and sharp (no dithering on text).
ffmpeg -loglevel error -i "$work/demo.mkv" -vf "fps=12,palettegen=max_colors=48:stats_mode=full" -y "$work/palette.png"
ffmpeg -loglevel error -i "$work/demo.mkv" -i "$work/palette.png" \
  -lavfi "fps=12 [x]; [x][1:v] paletteuse=dither=none" -loop 0 -y "$out"
echo "wrote $out ($(du -h "$out" | cut -f1))"
