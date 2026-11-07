# Development without Nix

`nix develop` provides everything (flake.nix). This page is the manual
equivalent, as used in the Debian 12 sandbox where Shipinel is developed.

## System packages (Debian 12)

```sh
apt install build-essential cmake pkg-config fontconfig \
  libwayland-dev libwayland-bin wayland-protocols libxkbcommon-dev \
  libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
  libgl-dev libegl-dev clang-format clang-tidy cppcheck
```

Debian has no raylib 6.2 package (and only GLFW 3.3), so raylib is built
from its tag with the GLFW it bundles, which has both Wayland and X11
backends.

## raylib 6.2 and raygui 5.0 into ~/.local

```sh
git clone --depth 1 --branch 6.2 https://github.com/raysan5/raylib.git
git clone --depth 1 --branch 5.0 https://github.com/raysan5/raygui.git
cmake -S raylib -B raylib-build -DCMAKE_BUILD_TYPE=Release -DPLATFORM=Desktop \
  -DBUILD_SHARED_LIBS=ON -DBUILD_EXAMPLES=OFF -DUSE_EXTERNAL_GLFW=OFF \
  -DGLFW_BUILD_WAYLAND=ON -DGLFW_BUILD_X11=ON -DCMAKE_INSTALL_PREFIX=$HOME/.local
cmake --build raylib-build -j1
cmake --install raylib-build
install -m 644 raygui/src/raygui.h $HOME/.local/include/raygui.h
```

CMake's summary should say both "Including Wayland support" and "Including
X11 support".

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
