# Installing Shipinel without Nix

This bundle runs on x86_64 Linux with glibc 2.35 or newer (Ubuntu 22.04,
Debian 12, Fedora 36 and later), on Wayland or X11. It carries its own
raylib and GLFW; the rest comes from your system.

## 1. What your system needs

Most desktops have all of it. On Debian or Ubuntu:

```sh
sudo apt install libsystemd0 libgl1 libegl1 fontconfig xdg-utils libnotify-bin
```

On Fedora: `sudo dnf install systemd-libs mesa-libGL mesa-libEGL fontconfig xdg-utils libnotify`.

- `fontconfig` (`fc-match`) picks the text fonts.
- `xdg-utils` (`xdg-open`) opens links you click.
- `libnotify` (`notify-send`) shows the notifications.

Emoji and symbols need a **monochrome** emoji font (raylib cannot draw
colour emoji). Shipinel asks fontconfig for one; if you have none, install
Noto Emoji (the monochrome one, from https://fonts.google.com/noto/specimen/Noto+Emoji)
into `~/.local/share/fonts`, or pass `--emoji-font PATH`.

## 2. Install

```sh
tar -xzf shipinel-*-linux-x86_64.tar.gz
mkdir -p ~/.local/opt
mv shipinel-*-linux-x86_64 ~/.local/opt/shipinel
mkdir -p ~/.local/bin
ln -sf ~/.local/opt/shipinel/bin/shipinel ~/.local/bin/shipinel
shipinel --version
```

(`~/.local/bin` must be on your `PATH`.) To update, replace
`~/.local/opt/shipinel` with the new version.

## 3. Run

```sh
shipinel ~/notes/week.md
```

`config.example` explains every setting; copy it to
`~/.config/shipinel/config` to use it. The README on GitHub has the keys,
the supported Markdown and the window rules for KDE, Hyprland and GNOME:
https://github.com/fabiosammy/shipinel

## Licenses

Shipinel is MIT licensed. The bundled raylib, raygui and GLFW are under the
zlib/libpng license; all texts are in `licenses/`.
