# Development without Nix

`nix develop` provides everything (flake.nix). This page is the manual
equivalent, as used in the Debian 12 sandbox where Shipinel is developed.

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

`packaging/linux/build.sh WORK_DIR` builds the bundle for people without
Nix from scratch (Spinel, GLFW, raylib, then Shipinel) into
`WORK_DIR/shipinel-<version>-linux-x86_64.tar.gz`; it also needs `patchelf`.
CI builds it on Ubuntu 22.04, the oldest glibc it supports.

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
(`apt install xvfb`):

```sh
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
DISPLAY=:99 build/bin/shipinel test/fixtures/semana.md
```

Never drive the real display with XTest or similar: synthetic clicks go to
whatever window is on top there.
