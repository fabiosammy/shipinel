# Tray icon notes

The tray icon (`ext/tray.c`, used through `Tray`, `TrayIcon` and `Desktop`)
is a StatusNotifierItem with a dbusmenu context menu on the session bus,
through sd-bus (libsystemd). It is shown only with `tray=on` in the config.

## Where it shows

| Desktop | Tray host |
|---|---|
| KDE Plasma | built in |
| Hyprland | a bar with a tray, e.g. waybar's `tray` module |
| GNOME | the AppIndicator extension |

Without a host (no `org.kde.StatusNotifierWatcher` on the bus) `tray_open`
answers 0: Shipinel prints one line on stderr and `close_to_tray` is
ignored, so the window can never be hidden with no way back. A host that
starts or restarts later (plasmashell can) gets the icon again: the tray
watches `NameOwnerChanged` for the watcher's name.

## StatusNotifierItem (`/StatusNotifierItem`, `org.kde.StatusNotifierItem`)

Service name `org.kde.StatusNotifierItem-<pid>-1`, registered with
`org.kde.StatusNotifierWatcher.RegisterStatusNotifierItem(s)`.

| Member | Signature | Shipinel's |
|---|---|---|
| `Category`, `Id`, `Title`, `Status` | `s` | `ApplicationStatus`, `shipinel`, "Shipinel · <file>", `Active` |
| `IconName`, `OverlayIconName`, `AttentionIconName`, `AttentionMovieName` | `s` | empty: the icon is a pixmap |
| `IconPixmap` | `a(iiay)` | one 32 × 32 ARGB32 image, network byte order: a ring filled clockwise from the top by the share of checked tasks, green when all are |
| `OverlayIconPixmap`, `AttentionIconPixmap` | `a(iiay)` | empty |
| `ToolTip` | `(sa(iiay)ss)` | no icon; title, and "12 of 40 tasks done · 30%" |
| `WindowId`, `ItemIsMenu`, `Menu` | `i`, `b`, `o` | 0, false, `/MenuBar` |
| `Activate(ii)`, `SecondaryActivate(ii)` | | show or hide the window |
| `ContextMenu(ii)`, `Scroll(is)` | | nothing (the host shows the dbusmenu) |
| signals `NewIcon`, `NewToolTip` | | sent when the progress changes |

## dbusmenu (`/MenuBar`, `com.canonical.dbusmenu`, version 3)

Items: 0 the root (`children-display: submenu`), 1 "Show / hide window",
2 a separator, 3 "Quit". The menu never changes, so the layout revision
stays 1 and `AboutToShow` answers false.

| Method | Signature |
|---|---|
| `GetLayout` | `(iias) -> u(ia{sv}av)` |
| `GetGroupProperties` | `(aias) -> a(ia{sv})` |
| `GetProperty` | `(is) -> v` |
| `Event` | `(isvu)`: only `clicked` acts |
| `EventGroup` | `(a(isvu)) -> ai` |
| `AboutToShow` / `AboutToShowGroup` | `(i) -> b` / `(ai) -> aiai` |

## sd-bus calls (systemd/sd-bus.h, libsystemd 252)

```c
int sd_bus_open_user(sd_bus **ret);                                                    // sd-bus.h:137
int sd_bus_request_name(sd_bus *bus, const char *name, uint64_t flags);                // sd-bus.h:349
int sd_bus_add_object_vtable(sd_bus *bus, sd_bus_slot **slot, const char *path, const char *interface, const sd_bus_vtable *vtable, void *userdata); // sd-bus.h:235
int sd_bus_match_signal(sd_bus *bus, sd_bus_slot **ret, const char *sender, const char *path, const char *interface, const char *member, sd_bus_message_handler_t callback, void *userdata); // sd-bus.h:396
int sd_bus_call_method(sd_bus *bus, const char *destination, const char *path, const char *interface, const char *member, sd_bus_error *ret_error, sd_bus_message **reply, const char *types, ...); // sd-bus.h:361
int sd_bus_call_method_async(sd_bus *bus, sd_bus_slot **slot, const char *destination, const char *path, const char *interface, const char *member, sd_bus_message_handler_t callback, void *userdata, const char *types, ...); // sd-bus.h:363
int sd_bus_process(sd_bus *bus, sd_bus_message **r);                                   // sd-bus.h:209
int sd_bus_get_fd(sd_bus *bus);                                                        // sd-bus.h:206
int sd_bus_emit_signal(sd_bus *bus, const char *path, const char *interface, const char *member, const char *types, ...); // sd-bus.h:381
int sd_bus_reply_method_return(sd_bus_message *call, const char *types, ...);          // sd-bus.h:372
sd_bus* sd_bus_flush_close_unref(sd_bus *bus);                                         // sd-bus.h:189
typedef int (*sd_bus_property_get_t)(sd_bus *bus, const char *path, const char *interface, const char *property, sd_bus_message *reply, void *userdata, sd_bus_error *ret_error); // sd-bus.h:112
```

Messages are built with `sd_bus_message_open_container` /
`close_container` / `append` / `append_array` and read with `read`,
`skip`, `enter_container` / `exit_container`.

## Threads and waking up

All sd-bus calls run on the main thread, in `tray_next_event` once a frame.
The waker thread (ui_shim.c) only `poll`s the bus's file descriptor beside
its stop pipe: a message posts a GLFW empty event, so a click on the icon
wakes an idle window at once. Closing the window stops the waker first,
then closes the bus (`ui_close_window`).

## Checked

In the dev sandbox, inside `dbus-run-session` (a private bus) with a
stand-in watcher: the item registers; `ToolTip`, `Menu`, `IconPixmap`,
`GetLayout` and `GetGroupProperties` answer as above; `Activate` hides and
shows the window; with `close_to_tray` the close button hides it and the
process keeps running; `Event(3, "clicked")` quits.

## Turning the icon off and on while running (2026-11-08)

The config can change `tray=` in a running window (Desktop#follow_config).
Ruby calls `tray_close` (`ui.rb`) through `Tray#close`, which first shows
the window (it may be hidden in the icon), and `tray_open` again for a new
icon. The waker thread re-reads `tray_bus_fd()` on every loop and treats a
new fd as usable again, so a bus that was closed (or failed) does not keep
a new one out. Checked on a private bus with the stand-in watcher: the
icon's name appears and disappears with the config, and a window hidden in
the icon comes back when it goes.

