#!/usr/bin/env bash
# Builds Shipinel for people without Nix: one executable with raylib and
# GLFW linked in, and a tarball with that executable, the desktop entry and
# the icon. Everything else comes from the system (glibc, libsystemd,
# libX11, the OpenGL driver, and at run time fc-match, xdg-open and
# notify-send), so the build runs on the oldest system it should support:
# CI builds on Ubuntu 22.04 (glibc 2.35).
#
# Usage: packaging/linux/build.sh WORK_DIR
# Writes WORK_DIR/shipinel-linux-x86_64 (the executable),
# WORK_DIR/shipinel-linux-x86_64.tar.gz and WORK_DIR/SHA256SUMS.
# Needs: a C compiler, cmake, pkg-config, ruby (Spinel's build), curl, git,
# and the -dev packages in docs/development.md.
set -euo pipefail

work=$(realpath "$1")
source_dir=$(realpath "$(dirname "$0")/../..")
prefix=$work/prefix
version=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$source_dir/spin.toml")
# The release's file names carry no version, so
# .../releases/latest/download/shipinel-linux-x86_64 always works.
single=shipinel-linux-x86_64

# The same versions flake.nix builds with, pinned by content: the Spinel
# tarball by its sha256 (flake.nix has it in SRI form), raylib and raygui
# by the commit their tag pointed at.
spinel_version=2026.10.25
spinel_sha256=e13c7360e4f845b4a6b9f34a80fb6b827f950a480d1aa339e6cb25e5cb61a3b0
raylib_tag=6.2
raylib_commit=02566453880e06bec97f5b8160fa6fe1e98397ca
raygui_tag=5.0
raygui_commit=020a61bebcbe288b4414de3416e219ef40af847a

mkdir -p "$work" "$prefix"
cd "$work"

# Clones `repo` at `tag` and fails unless the tag is still `commit`.
fetch_tag() {
  local repo=$1 tag=$2 commit=$3 dir=$4
  git clone --quiet --depth 1 --branch "$tag" "https://github.com/$repo.git" "$dir"
  if [ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]; then
    echo "$repo $tag is no longer commit $commit"
    exit 1
  fi
}

echo "== Spinel $spinel_version"
curl --fail --location --silent --show-error --output spinel.tar.xz \
  "https://github.com/matz/spinel/releases/download/$spinel_version/spinel-$spinel_version.tar.xz"
echo "$spinel_sha256  spinel.tar.xz" | sha256sum --check
tar -xf spinel.tar.xz
make -C "spinel-$spinel_version" all tools
make -C "spinel-$spinel_version" install "PREFIX=$prefix"

# GLFW from the copy raylib bundles (both backends) and raylib against
# it, as static libraries, so they end up inside the one executable. The
# shim calls GLFW itself (docs/development.md). A static GLFW is
# libglfw3.a; ui.rb's ffi_lib "glfw" links -lglfw, hence the second name.
echo "== GLFW and raylib $raylib_tag"
fetch_tag raysan5/raylib "$raylib_tag" "$raylib_commit" raylib
fetch_tag raysan5/raygui "$raygui_tag" "$raygui_commit" raygui
cmake -S raylib/src/external/glfw -B glfw-build -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DGLFW_BUILD_WAYLAND=ON -DGLFW_BUILD_X11=ON \
  -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
  -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib
cmake --build glfw-build -j1
cmake --install glfw-build
ln -sf libglfw3.a "$prefix/lib/libglfw.a"
cmake -S raylib -B raylib-build -DCMAKE_BUILD_TYPE=Release -DPLATFORM=Desktop \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DUSE_EXTERNAL_GLFW=ON \
  -DCMAKE_PREFIX_PATH="$prefix" -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib
cmake --build raylib-build -j1
cmake --install raylib-build
install -m 644 raygui/src/raygui.h "$prefix/include/raygui.h"

# A static raylib calls libX11 itself (its X11 clipboard code), which a
# shared one brought along. Spinel links with the `cc` on PATH, so this one
# adds -lX11 at the end of every link (not to -c compiles).
real_cc=$(command -v cc)
mkdir -p "$work/cc-bin"
cat > "$work/cc-bin/cc" <<CC
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "-c" ]; then
    exec $real_cc "\$@"
  fi
done
exec $real_cc "\$@" -lX11
CC
chmod +x "$work/cc-bin/cc"

echo "== shipinel $version"
rm -rf build-src
cp -r "$source_dir" build-src
rm -rf build-src/build
export PATH=$work/cc-bin:$prefix/bin:$PATH
export PKG_CONFIG_PATH=$prefix/lib/pkgconfig
export LIBRARY_PATH=$prefix/lib
export C_INCLUDE_PATH=$prefix/include
(cd build-src && HOME=$work spin build)

# The single file: everything but glibc, libm, libsystemd, libX11 and what
# GLFW opens at run time (the OpenGL driver, X11 or Wayland) is inside.
echo "== $single"
install -m 755 build-src/build/bin/shipinel "$single"

# The tarball: the same executable, with the desktop entry, the icon, the
# example config and the licenses.
echo "== $single.tar.gz"
rm -rf shipinel
mkdir -p shipinel/bin shipinel/licenses
install -m 755 "$single" shipinel/bin/shipinel
install -m 644 "$source_dir/LICENSE" shipinel/licenses/shipinel.txt
install -m 644 raylib/LICENSE shipinel/licenses/raylib.txt
install -m 644 raylib/src/external/glfw/LICENSE.md shipinel/licenses/glfw.txt
install -m 644 raygui/LICENSE shipinel/licenses/raygui.txt
install -m 644 "$source_dir/docs/config.example" shipinel/config.example
install -m 644 "$source_dir/packaging/linux/INSTALL.md" shipinel/INSTALL.md
install -D -m 644 "$source_dir/packaging/shipinel.desktop" shipinel/share/applications/shipinel.desktop
install -D -m 644 "$source_dir/packaging/shipinel.svg" shipinel/share/icons/hicolor/scalable/apps/shipinel.svg
tar -czf "$single.tar.gz" shipinel

sha256sum "$single" "$single.tar.gz" > SHA256SUMS
echo "== built $work/$single, $work/$single.tar.gz and $work/SHA256SUMS ($version)"
ldd "$single"
