# Development without Nix

`nix develop` provides everything (flake.nix). This page is the manual
equivalent, as used in the Debian 12 sandbox where Shipinel is developed.

**Run the gate through the flake even there:**
`nix develop -c bundle exec rake check`. Its tools are the ones CI uses
(the newer clang-tidy, actionlint, cppcheck), they live in the Nix store,
which survives a rebuilt container, and nothing has to be linked into
`~/.local` by hand. The manual setup below is for building and running the
window against the system's Mesa.

## System packages (Debian 12)

```sh
apt install build-essential cmake pkg-config fontconfig \
  libwayland-dev libwayland-bin wayland-protocols libxkbcommon-dev \
  libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libgl-dev libegl-dev libsystemd-dev clang-format clang-tidy cppcheck yamllint
```

Debian has no raylib 6.2 package (and only GLFW 3.3), so GLFW is built as
a shared library from the copy raylib bundles (3.5.1, Wayland and X11
backends), and raylib is built against it. The shim calls GLFW itself
(event waiting, docs/raylib-notes.md), so raylib must not hide its own
copy: `USE_EXTERNAL_GLFW=ON`, as nixpkgs builds it.

## GLFW, raylib 6.2 and raygui 5.0 into ~/.local

```sh
git clone --depth 1 --branch 6.2 https://github.com/raysan5/raylib.git
git clone --depth 1 --branch 5.0 https://github.com/raysan5/raygui.git
cmake -S raylib/src/external/glfw -B glfw-build -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_WAYLAND=ON -DGLFW_BUILD_X11=ON \
  -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
  -DCMAKE_INSTALL_PREFIX=$HOME/.local
cmake --build glfw-build -j1
cmake --install glfw-build
cmake -S raylib -B raylib-build -DCMAKE_BUILD_TYPE=Release -DPLATFORM=Desktop \
  -DBUILD_SHARED_LIBS=ON -DBUILD_EXAMPLES=OFF -DUSE_EXTERNAL_GLFW=ON \
  -DCMAKE_PREFIX_PATH=$HOME/.local -DCMAKE_INSTALL_PREFIX=$HOME/.local
cmake --build raylib-build -j1
cmake --install raylib-build
install -m 644 raygui/src/raygui.h $HOME/.local/include/raygui.h
```

GLFW's CMake summary should say both "Including Wayland support" and
"Including X11 support"; raylib's should say "Using external GLFW".
`ldd build/bin/shipinel` then lists `libglfw.so.3` from `~/.local/lib`.

`libsystemd-dev` brings sd-bus, which the tray icon uses (docs/tray-notes.md).

Debian 12 has no actionlint package. Take the one the flake pins, which
comes wrapped with shellcheck:
`nix build --inputs-from . nixpkgs#actionlint -o ~/.cache/actionlint` and
link `~/.cache/actionlint/bin/actionlint` into `~/.local/bin`.

shellcheck (for `rake shell_checks`) and desktop-file-validate (for `rake
desktop_checks`) come from apt (`apt install shellcheck desktop-file-utils`)
or the same way as actionlint (`nixpkgs#shellcheck`,
`nixpkgs#desktop-file-utils`).

## The Linux bundle and the window test

`packaging/linux/build.sh WORK_DIR` builds Shipinel for people without Nix
from scratch (Spinel, then GLFW and raylib as static libraries, then
Shipinel) into `WORK_DIR/shipinel-linux-x86_64` (one executable that links
only glibc, libm, libsystemd and libX11), `shipinel-linux-x86_64.tar.gz`
(the same with the desktop entry and icon) and `SHA256SUMS`. A static
raylib calls libX11 itself and Spinel links with the `cc` on `PATH`, so the
script puts a `cc` first that adds `-lX11` to links; a static GLFW is
`libglfw3.a`, linked as `libglfw.a` too for `ffi_lib "glfw"`. CI builds it
on Ubuntu 22.04, the oldest glibc it supports.

`test/window/run.sh PATH/TO/shipinel` opens that binary in its own Xvfb
(`apt install xvfb xdotool libgl1-mesa-dri`), clicks a task, presses `u`
and `h`, and checks the file and the saved state. It picks a display
number with no socket and no lock, so it never takes a desktop's display.

The sandbox's clang-tidy (LLVM 14) is older than the flake's, which knows
more checks: run `nix flake check` before pushing, as CI does.

## Spinel 2026.10.25

Build the pinned release tarball (hash in docs/spinel-notes.md) with
`make && make tools && make install PREFIX=$HOME/.local`, then
`install -m 755 bin/spinel-diff $HOME/.local/lib/spinel/` so `spinel diff`
finds its tool (the release's install misses it).

## Environment for every command

```sh
export PATH=$HOME/.local/bin:$PATH
export PKG_CONFIG_PATH=$HOME/.local/lib/pkgconfig   # spin + rake find raylib.h
export LIBRARY_PATH=$HOME/.local/lib                # the linker finds -lraylib
export LD_LIBRARY_PATH=$HOME/.local/lib             # the binary finds libraylib.so
bundle config set --local path ~/.cache/shipinel-bundle   # once; see spinel-notes
bundle install
bundle exec rake check
spin build && build/bin/shipinel test/fixtures/semana.md
```

## Trying the window without touching your desktop

A virtual X server keeps synthetic input away from the real display
(`apt install xvfb xauth xdotool xclip`; the clausea image has them, with
`sandbox-xvfb`). Start it on a fixed number whose socket and lock do not
exist (`sandbox-xvfb [N]` checks that): `/tmp/.X11-unix` may be shared with
the host, and a number Xvfb picks itself can be the desktop's.

```sh
sandbox-xvfb 99     # or: Xvfb :99 -screen 0 1280x900x24 -nolisten tcp +extension GLX &
env -u XAUTHORITY DISPLAY=:99 build/bin/shipinel test/fixtures/semana.md
```

`xdotool` drives it (keys, clicks, drags) and `xclip -selection clipboard
-o` reads back what Ctrl+C copied.

Never drive the real display with XTest or similar: synthetic clicks go to
whatever window is on top there.

## The README's animations

`docs/demo/record.sh PATH/TO/shipinel OUT.gif [SCENE]` records the example
week in its own Xvfb: it builds `docs/demo/clock.c` (an `LD_PRELOAD` that
moves the wall clock to Wednesday 2026-11-11 15:30, and leaves itself out
of the programs Shipinel starts), plays one scene and turns the recording
into a GIF with a small palette. The scenes: `overview` (`docs/demo.gif`:
a tick, an outside edit, scrolling, `u` and `h`), `find`
(`docs/demo-find.gif`), `keys` (`docs/demo-keys.gif`: Tab and Space, the
outline, the help) and `select` (`docs/demo-select.gif`). The still
`docs/screenshot.png` is the overview's first half second. It needs xdotool and an ffmpeg
with x11grab (Debian's `ffmpeg`, or `nixpkgs#ffmpeg-full`; plain
`nixpkgs#ffmpeg` has no X11 capture). Use the fonts of the still image
(Liberation Sans through `FONTCONFIG_FILE`) so the two match. The pointer
is not recorded: Xvfb has only its bare "X" cursor.

