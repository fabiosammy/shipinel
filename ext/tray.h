/*
 * The tray icon: a StatusNotifierItem (the protocol KDE Plasma, waybar's
 * tray and GNOME's AppIndicator extension show) with a dbusmenu context
 * menu, on the session bus through sd-bus. The rest of the app never sees
 * D-Bus: it opens the icon, sets the progress it shows, and reads what the
 * user did with it. Everything runs on the main thread, except that the
 * waker thread in ui_shim.c polls tray_bus_fd to wake an idle frame.
 */
#ifndef SHIPINEL_TRAY_H
#define SHIPINEL_TRAY_H

/* What tray_next_event answers. */
enum {
    TRAY_NONE = 0,
    /* A click on the icon, or the menu's "Show / hide window". */
    TRAY_TOGGLE = 1,
    /* The menu's "Quit". */
    TRAY_QUIT = 2
};

/* 1 when a tray host took the icon; 0 when there is no session bus or no
 * StatusNotifierWatcher (GNOME without the extension). `title` names the
 * icon in the host's lists and tooltip. */
int tray_open(const char *title);

/* The tooltip's text and the ring on the icon, filled `permille` / 1000;
 * the ring is green at 1000. Signals the host only when something changed. */
void tray_show_progress(const char *label, int permille);

/* Handles whatever the bus delivered, then answers the last click since the
 * previous call (TRAY_QUIT wins over TRAY_TOGGLE). TRAY_NONE without a tray. */
int tray_next_event(void);

/* The bus connection's file descriptor, -1 without a tray. Safe to read
 * from the waker thread. */
int tray_bus_fd(void);

/* Takes the icon away. Called by ui_close_window after the waker stopped. */
void tray_close(void);

#endif
