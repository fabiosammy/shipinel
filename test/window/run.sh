#!/usr/bin/env bash
# The window test: opens the built Shipinel in a virtual X display (Xvfb,
# drawn by Mesa's software renderer) and drives it like a user with
# xdotool. It checks what the unit tests cannot reach: that the native
# window opens, draws, and turns real key presses and clicks into changes
# of the file and the saved state.
#
# Usage: test/window/run.sh PATH/TO/shipinel
# Needs Xvfb, xdotool and Mesa's software OpenGL driver (CI: "12 · Linux
# bundle" installs them on Ubuntu). It starts its own display on a number
# nobody uses, and never touches a real one.
set -euo pipefail

shipinel=$1
work=$(mktemp -d)
plan=$work/plan.md
state_dir=$work/state/shipinel

# Waits up to 10 seconds for `file` to hold the line `expected`, so a slow
# software-rendered frame (a CI runner) is not mistaken for a failure, and
# no step starts before the app took the one before it.
wait_for_line() {
  local file=$1 expected=$2
  for _ in $(seq 100); do
    if [ -f "$file" ] && grep -qxF -- "$expected" "$file"; then
      return 0
    fi
    sleep 0.1
  done
  echo "FAIL: $file never held the line '$expected'; it holds:"
  cat "$file"
  return 1
}

# Presses a key for 100 ms. `xdotool key` releases at once, and a key that
# goes down and up between two of raylib's input polls is never seen as
# pressed; a person's key press lasts longer.
press() {
  xdotool keydown --window "$window" "$1"
  sleep 0.1
  xdotool keyup --window "$window" "$1"
}

# Clicks at x y in the window, holding the button for 100 ms (as `press`).
click_at() {
  xdotool mousemove --window "$window" "$1" "$2" mousedown 1
  sleep 0.1
  xdotool mouseup 1
}

# Stops the app once it was started, then the display (waiting for the app
# first, so it does not report a lost display), whether the test passed or
# not.
stop() {
  if [ -n "${app:-}" ]; then
    kill "$app"
    tail --pid="$app" -f /dev/null
  fi
  kill "$xvfb"
}

printf -- '- [ ] Ship the window test\n' > "$plan"

# A display number nobody uses: no socket and no lock. Xvfb's own pick
# only looks at lock files and replaces an existing socket, which would
# take a real desktop's display away where /tmp/.X11-unix is shared (a
# container). Starts at 90, far from the desktops' :0 to :2.
number=90
while [ -e "/tmp/.X11-unix/X$number" ] || [ -e "/tmp/.X$number-lock" ]; do
  number=$((number + 1))
done

# -displayfd: Xvfb writes the number once it accepts clients, so nothing
# connects too early.
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
echo "Xvfb is ready on $DISPLAY"
export XDG_STATE_HOME=$work/state XDG_CONFIG_HOME=$work/config
unset XAUTHORITY WAYLAND_DISPLAY

"$shipinel" "$plan" &
app=$!

# The window shows up under its fixed title; no window manager runs, so it
# gets the keyboard focus by hand.
window=$(timeout 30 xdotool search --sync --name '^shipinel$' | head -n 1)
echo "window $window is open"
xdotool windowfocus --sync "$window"

# The state file is written by the app's loop (within half a second of a
# change, and the first time on its first chores): once it says the header
# shows, the window is drawn and takes input.
state=$state_dir/$(printf '%s' "$plan" | tr / %)
wait_for_line "$state" 'header=1'
echo "the window is drawn"

# h hides the header, so the first task's checkbox sits at the page's top
# margin: 16 px in, its center 29 px down at --font-size 20. The saved
# state says when h was taken.
press h
wait_for_line "$state" 'header=0'
echo "h hid the header, and it was saved"

click_at 24 29
wait_for_line "$plan" '- [x] Ship the window test'
echo "a click ticked the task"

press u
wait_for_line "$plan" '- [ ] Ship the window test'
echo "u undid the tick"

kill -0 "$app"
echo "PASS: the window opened, hid its header, ticked and undid"
