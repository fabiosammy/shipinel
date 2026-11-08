#!/usr/bin/env bash
# Builds the Linux bundle for people without Nix: a tarball with the
# shipinel binary and the raylib and GLFW it was built with, found next to
# it ($ORIGIN/../lib). Everything else comes from the system (glibc,
# libsystemd, the OpenGL driver, and at run time fc-match, xdg-open and
# notify-send), so the build runs on the oldest system it should support:
# CI builds on Ubuntu 22.04 (glibc 2.35).
#
# Usage: packaging/linux/build.sh WORK_DIR
# Writes WORK_DIR/shipinel-<version>-linux-x86_64.tar.gz and its .sha256.
# Needs: a C compiler, cmake, pkg-config, ruby (Spinel's build), curl, git,
# patchelf, and the -dev packages in docs/development.md.
set -euo pipefail

work=$(realpath "$1")
source_dir=$(realpath "$(dirname "$0")/../..")
prefix=$work/prefix
version=$(sed -n 's/^version = "\(.*\)"$/\1/p' "$source_dir/spin.toml")
bundle=shipinel-$version-linux-x86_64

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

# GLFW from the copy raylib bundles, built shared with both backends, and
# raylib against it: the shim calls GLFW itself (docs/development.md).
echo "== GLFW and raylib $raylib_tag"
fetch_tag raysan5/raylib "$raylib_tag" "$raylib_commit" raylib
fetch_tag raysan5/raygui "$raygui_tag" "$raygui_commit" raygui
cmake -S raylib/src/external/glfw -B glfw-build -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_WAYLAND=ON -DGLFW_BUILD_X11=ON \
  -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
  -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib
cmake --build glfw-build -j1
cmake --install glfw-build
cmake -S raylib -B raylib-build -DCMAKE_BUILD_TYPE=Release -DPLATFORM=Desktop \
  -DBUILD_SHARED_LIBS=ON -DBUILD_EXAMPLES=OFF -DUSE_EXTERNAL_GLFW=ON \
  -DCMAKE_PREFIX_PATH="$prefix" -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib
cmake --build raylib-build -j1
cmake --install raylib-build
install -m 644 raygui/src/raygui.h "$prefix/include/raygui.h"

echo "== shipinel $version"
rm -rf build-src
cp -r "$source_dir" build-src
rm -rf build-src/build
export PATH=$prefix/bin:$PATH
export PKG_CONFIG_PATH=$prefix/lib/pkgconfig
export LIBRARY_PATH=$prefix/lib
export C_INCLUDE_PATH=$prefix/include
(cd build-src && HOME=$work spin build)

echo "== $bundle"
rm -rf "$bundle"
mkdir -p "$bundle/bin" "$bundle/lib" "$bundle/licenses"
install -m 755 build-src/build/bin/shipinel "$bundle/bin/shipinel"
cp -P "$prefix"/lib/libraylib.so.* "$prefix"/lib/libglfw.so.* "$bundle/lib/"
# The binary finds raylib, and raylib finds GLFW, next to themselves.
patchelf --set-rpath "\$ORIGIN/../lib" "$bundle/bin/shipinel"
patchelf --set-rpath "\$ORIGIN" "$bundle"/lib/libraylib.so.*.*.*
install -m 644 "$source_dir/LICENSE" "$bundle/licenses/shipinel.txt"
install -m 644 raylib/LICENSE "$bundle/licenses/raylib.txt"
install -m 644 raylib/src/external/glfw/LICENSE.md "$bundle/licenses/glfw.txt"
install -m 644 raygui/LICENSE "$bundle/licenses/raygui.txt"
install -m 644 "$source_dir/docs/config.example" "$bundle/config.example"
install -m 644 "$source_dir/packaging/linux/INSTALL.md" "$bundle/INSTALL.md"

tar -czf "$bundle.tar.gz" "$bundle"
sha256sum "$bundle.tar.gz" > "$bundle.tar.gz.sha256"
echo "== built $work/$bundle.tar.gz"
ldd "$bundle/bin/shipinel"
