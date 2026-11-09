# Installing Shipinel without Nix

`bin/shipinel` is one executable with raylib and GLFW inside. It runs on
x86_64 Linux with glibc 2.35 or newer (Ubuntu 22.04, Debian 12, Fedora 36
and later), on Wayland or X11. The rest comes from your system.

## 1. What your system needs

Most desktops have all of it. On Debian or Ubuntu:

```sh
sudo apt install libsystemd0 libx11-6 libgl1 libegl1 fontconfig xdg-utils libnotify-bin
```

On Fedora: `sudo dnf install systemd-libs libX11 mesa-libGL mesa-libEGL fontconfig xdg-utils libnotify`.

- `fontconfig` (`fc-match`) picks the text fonts.
- `xdg-utils` (`xdg-open`) opens links you click.
- `libnotify` (`notify-send`) shows the notifications.

Emoji and symbols need a **monochrome** emoji font (raylib cannot draw
colour emoji). Shipinel asks fontconfig for one; if you have none, install
Noto Emoji (the monochrome one, from https://fonts.google.com/noto/specimen/Noto+Emoji)
into `~/.local/share/fonts`, or pass `--emoji-font PATH`.

## 2. Install

From the directory with the tarball:

```sh
mkdir -p ~/.local/opt ~/.local/bin
tar -xzf shipinel-linux-x86_64.tar.gz -C ~/.local/opt
ln -sf ~/.local/opt/shipinel/bin/shipinel ~/.local/bin/shipinel
shipinel --version
```

(`~/.local/bin` must be on your `PATH`.) To update, unpack the new
tarball the same way.

For the app launcher and the icon, install the desktop entry with the full
path to the executable (the session's `PATH` may not have `~/.local/bin`):

```sh
mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/scalable/apps
sed "s|^Exec=shipinel|Exec=$HOME/.local/opt/shipinel/bin/shipinel|" \
  ~/.local/opt/shipinel/share/applications/shipinel.desktop \
  > ~/.local/share/applications/shipinel.desktop
cp ~/.local/opt/shipinel/share/icons/hicolor/scalable/apps/shipinel.svg \
  ~/.local/share/icons/hicolor/scalable/apps/
```

To start it with your session, copy that entry into `~/.config/autostart/`
(or see "Start with your session" in the README for Hyprland).

## 3. Run

```sh
shipinel ~/notes/week.md
```

`config.example` explains every setting; copy it to
`~/.config/shipinel/config` to use it. The README on GitHub has the keys,
the supported Markdown and the window rules for KDE, Hyprland and GNOME:
https://github.com/fabiosammy/shipinel

## Licenses

Shipinel is MIT licensed. The raylib, raygui and GLFW inside it are under
the zlib/libpng license; all texts are in `licenses/`.
