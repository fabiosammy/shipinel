/*
 * See tray.h. Protocols: StatusNotifierItem
 * (https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/) and
 * com.canonical.dbusmenu; signatures and the sd-bus calls used are listed in
 * docs/tray-notes.md.
 */

/* getpid is POSIX, not C11. This feature-test macro is how POSIX asks for
 * it; its name is reserved because the C library reads it
 * (docs/exceptions.md). */
// NOLINTNEXTLINE(bugprone-reserved-identifier)
#define _POSIX_C_SOURCE 200809L

#include "tray.h"

#include <math.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <systemd/sd-bus.h>
#include <unistd.h>

enum {
    /* The icon is drawn once at this size; hosts scale it. */
    ICON_SIZE = 32,
    BYTES_PER_PIXEL = 4,
    /* dbusmenu item ids; 0 is the menu itself. */
    MENU_ROOT = 0,
    MENU_TOGGLE = 1,
    MENU_SEPARATOR = 2,
    MENU_QUIT = 3,
    DBUSMENU_VERSION = 3,
    NAME_SIZE = 96,
    TEXT_SIZE = 256,
    PERMILLE_FULL = 1000
};

static const char *const ITEM_PATH = "/StatusNotifierItem";
static const char *const ITEM_INTERFACE = "org.kde.StatusNotifierItem";
static const char *const MENU_PATH = "/MenuBar";
static const char *const MENU_INTERFACE = "com.canonical.dbusmenu";
static const char *const WATCHER = "org.kde.StatusNotifierWatcher";
static const char *const WATCHER_PATH = "/StatusNotifierWatcher";

/* The ring's radii in pixels, measured from the icon's center. */
static const double RING_OUTER = 15.0;
static const double RING_INNER = 10.0;
static const double FULL_TURN = 6.283185307179586;

/* Ring colors, as alpha, red, green, blue (the theme's track, fill and
 * complete colors, lib/shipinel/theme.rb). */
static const uint8_t TRACK_COLOR[BYTES_PER_PIXEL] = {0xFF, 0x6B, 0x72, 0x80};
static const uint8_t FILL_COLOR[BYTES_PER_PIXEL] = {0xFF, 0x7A, 0xA2, 0xF7};
static const uint8_t COMPLETE_COLOR[BYTES_PER_PIXEL] = {0xFF, 0x98, 0xC3, 0x79};

static sd_bus *bus = NULL;
static atomic_int bus_fd = -1;
static char service_name[NAME_SIZE];
static char title_text[TEXT_SIZE];
static char progress_text[TEXT_SIZE];
static int progress_permille = -1;
static int pending_event = TRAY_NONE;
/* ARGB32 in network byte order, as StatusNotifierItem pixmaps are. */
static uint8_t icon_pixels[ICON_SIZE * ICON_SIZE * BYTES_PER_PIXEL];

static void copy_text(char *target, const char *source) {
    snprintf(target, TEXT_SIZE, "%s", source);
}

/* A newer click replaces an older one, except that Quit stays. */
static void remember_event(int event) {
    if (pending_event != TRAY_QUIT) {
        pending_event = event;
    }
}

/* Clockwise from the top, as a share of a full turn. */
static double turn_at(double across, double down) {
    const double angle = atan2(across, -down);
    return (angle < 0.0 ? angle + FULL_TURN : angle) / FULL_TURN;
}

static void paint_pixel(int index, const uint8_t *color) {
    memcpy(&icon_pixels[(size_t)index * BYTES_PER_PIXEL], color, BYTES_PER_PIXEL);
}

/* A ring filled clockwise from the top by the progress, on transparency. */
static void draw_icon(void) {
    const double share = (double)progress_permille / PERMILLE_FULL;
    const uint8_t *fill = progress_permille >= PERMILLE_FULL ? COMPLETE_COLOR : FILL_COLOR;
    const double center = ICON_SIZE / 2.0;
    memset(icon_pixels, 0, sizeof icon_pixels);
    for (int row = 0; row < ICON_SIZE; row++) {
        for (int column = 0; column < ICON_SIZE; column++) {
            const double across = column + 0.5 - center;
            const double down = row + 0.5 - center;
            const double distance = sqrt((across * across) + (down * down));
            if (distance <= RING_OUTER && distance >= RING_INNER) {
                paint_pixel((row * ICON_SIZE) + column,
                            turn_at(across, down) < share ? fill : TRACK_COLOR);
            }
        }
    }
}

static int append_pixmaps(sd_bus_message *reply, bool with_icon) {
    int result = sd_bus_message_open_container(reply, 'a', "(iiay)");
    if (result >= 0 && with_icon) {
        result = sd_bus_message_open_container(reply, 'r', "iiay");
        if (result >= 0) {
            result = sd_bus_message_append(reply, "ii", ICON_SIZE, ICON_SIZE);
        }
        if (result >= 0) {
            result = sd_bus_message_append_array(reply, 'y', icon_pixels, sizeof icon_pixels);
        }
        if (result >= 0) {
            result = sd_bus_message_close_container(reply);
        }
    }
    return result >= 0 ? sd_bus_message_close_container(reply) : result;
}

/* Icon name, icon pixmaps, title, description. */
static int append_tooltip(sd_bus_message *reply) {
    int result = sd_bus_message_open_container(reply, 'r', "sa(iiay)ss");
    if (result >= 0) {
        result = sd_bus_message_append(reply, "s", "");
    }
    if (result >= 0) {
        result = append_pixmaps(reply, false);
    }
    if (result >= 0) {
        result = sd_bus_message_append(reply, "ss", title_text, progress_text);
    }
    return result >= 0 ? sd_bus_message_close_container(reply) : result;
}

static const char *item_text(const char *property) {
    if (strcmp(property, "Category") == 0) {
        return "ApplicationStatus";
    }
    if (strcmp(property, "Id") == 0) {
        return "shipinel";
    }
    if (strcmp(property, "Title") == 0) {
        return title_text;
    }
    if (strcmp(property, "Status") == 0) {
        return "Active";
    }
    return "";
}

/* Every StatusNotifierItem property, by name. The parameters are
 * sd_bus_property_get_t's (docs/exceptions.md). */
// NOLINTNEXTLINE(bugprone-easily-swappable-parameters)
static int get_item_property(sd_bus *connection, const char *path, const char *interface,
                             const char *property, sd_bus_message *reply, void *userdata,
                             sd_bus_error *error) {
    (void)connection;
    (void)path;
    (void)interface;
    (void)userdata;
    (void)error;
    if (strcmp(property, "ToolTip") == 0) {
        return append_tooltip(reply);
    }
    if (strstr(property, "Pixmap") != NULL) {
        /* The real icon for IconPixmap; no overlay or attention pixmaps. */
        return append_pixmaps(reply, strcmp(property, "IconPixmap") == 0);
    }
    if (strcmp(property, "WindowId") == 0) {
        return sd_bus_message_append(reply, "i", 0);
    }
    if (strcmp(property, "ItemIsMenu") == 0) {
        return sd_bus_message_append(reply, "b", 0);
    }
    if (strcmp(property, "Menu") == 0) {
        return sd_bus_message_append(reply, "o", MENU_PATH);
    }
    return sd_bus_message_append(reply, "s", item_text(property));
}

/* A left (or middle) click on the icon shows or hides the window. */
static int on_activate(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    remember_event(TRAY_TOGGLE);
    return sd_bus_reply_method_return(message, "");
}

/* The host shows the dbusmenu itself; scrolling does nothing. */
static int on_ignored(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    return sd_bus_reply_method_return(message, "");
}

static const sd_bus_vtable ITEM_VTABLE[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_PROPERTY("Category", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("Id", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("Title", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("Status", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("IconName", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("OverlayIconName", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("AttentionIconName", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("AttentionMovieName", "s", get_item_property, 0, 0),
    SD_BUS_PROPERTY("IconPixmap", "a(iiay)", get_item_property, 0, 0),
    SD_BUS_PROPERTY("OverlayIconPixmap", "a(iiay)", get_item_property, 0, 0),
    SD_BUS_PROPERTY("AttentionIconPixmap", "a(iiay)", get_item_property, 0, 0),
    SD_BUS_PROPERTY("ToolTip", "(sa(iiay)ss)", get_item_property, 0, 0),
    SD_BUS_PROPERTY("WindowId", "i", get_item_property, 0, 0),
    SD_BUS_PROPERTY("ItemIsMenu", "b", get_item_property, 0, 0),
    SD_BUS_PROPERTY("Menu", "o", get_item_property, 0, 0),
    SD_BUS_METHOD("Activate", "ii", "", on_activate, 0),
    SD_BUS_METHOD("SecondaryActivate", "ii", "", on_activate, 0),
    SD_BUS_METHOD("ContextMenu", "ii", "", on_ignored, 0),
    SD_BUS_METHOD("Scroll", "is", "", on_ignored, 0),
    SD_BUS_SIGNAL("NewTitle", "", 0),
    SD_BUS_SIGNAL("NewIcon", "", 0),
    SD_BUS_SIGNAL("NewAttentionIcon", "", 0),
    SD_BUS_SIGNAL("NewOverlayIcon", "", 0),
    SD_BUS_SIGNAL("NewToolTip", "", 0),
    SD_BUS_SIGNAL("NewStatus", "s", 0),
    SD_BUS_VTABLE_END};

/* An item's properties: a{sv}. The root says it holds a submenu. */
static int append_menu_properties(sd_bus_message *reply, int item) {
    int result = sd_bus_message_open_container(reply, 'a', "{sv}");
    if (result < 0) {
        return result;
    }
    if (item == MENU_ROOT) {
        result = sd_bus_message_append(reply, "{sv}", "children-display", "s", "submenu");
    } else if (item == MENU_TOGGLE) {
        result = sd_bus_message_append(reply, "{sv}", "label", "s", "Show / hide window");
    } else if (item == MENU_SEPARATOR) {
        result = sd_bus_message_append(reply, "{sv}", "type", "s", "separator");
    } else if (item == MENU_QUIT) {
        result = sd_bus_message_append(reply, "{sv}", "label", "s", "Quit");
    }
    return result >= 0 ? sd_bus_message_close_container(reply) : result;
}

/* One layout node, (ia{sv}av), with no children of its own. */
static int append_menu_leaf(sd_bus_message *reply, int item) {
    int result = sd_bus_message_open_container(reply, 'r', "ia{sv}av");
    if (result >= 0) {
        result = sd_bus_message_append(reply, "i", item);
    }
    if (result >= 0) {
        result = append_menu_properties(reply, item);
    }
    if (result >= 0) {
        result = sd_bus_message_append(reply, "av", 0);
    }
    return result >= 0 ? sd_bus_message_close_container(reply) : result;
}

/* The root's children, each a variant holding its layout node. */
static int append_menu_children(sd_bus_message *reply) {
    int result = sd_bus_message_open_container(reply, 'a', "v");
    for (int item = MENU_TOGGLE; item <= MENU_QUIT && result >= 0; item++) {
        result = sd_bus_message_open_container(reply, 'v', "(ia{sv}av)");
        if (result >= 0) {
            result = append_menu_leaf(reply, item);
        }
        if (result >= 0) {
            result = sd_bus_message_close_container(reply);
        }
    }
    return result >= 0 ? sd_bus_message_close_container(reply) : result;
}

/* GetLayout(parent, depth, properties) -> (revision, layout): the whole
 * menu every time; it never changes, so the revision stays 1. */
static int on_get_layout(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    sd_bus_message *reply = NULL;
    int result = sd_bus_message_new_method_return(message, &reply);
    if (result >= 0) {
        result = sd_bus_message_append(reply, "u", 1U);
    }
    if (result >= 0) {
        result = sd_bus_message_open_container(reply, 'r', "ia{sv}av");
    }
    if (result >= 0) {
        result = sd_bus_message_append(reply, "i", MENU_ROOT);
    }
    if (result >= 0) {
        result = append_menu_properties(reply, MENU_ROOT);
    }
    if (result >= 0) {
        result = append_menu_children(reply);
    }
    if (result >= 0) {
        result = sd_bus_message_close_container(reply);
    }
    if (result >= 0) {
        result = sd_bus_send(NULL, reply, NULL);
    }
    sd_bus_message_unref(reply);
    return result;
}

/* GetGroupProperties(ids, properties) -> a(ia{sv}): every item when no id
 * is asked for. */
static int on_get_group_properties(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    sd_bus_message *reply = NULL;
    int result = sd_bus_message_new_method_return(message, &reply);
    if (result >= 0) {
        result = sd_bus_message_open_container(reply, 'a', "(ia{sv})");
    }
    for (int item = MENU_ROOT; item <= MENU_QUIT && result >= 0; item++) {
        result = sd_bus_message_open_container(reply, 'r', "ia{sv}");
        if (result >= 0) {
            result = sd_bus_message_append(reply, "i", item);
        }
        if (result >= 0) {
            result = append_menu_properties(reply, item);
        }
        if (result >= 0) {
            result = sd_bus_message_close_container(reply);
        }
    }
    if (result >= 0) {
        result = sd_bus_message_close_container(reply);
    }
    if (result >= 0) {
        result = sd_bus_send(NULL, reply, NULL);
    }
    sd_bus_message_unref(reply);
    return result;
}

static void menu_clicked(int item) {
    if (item == MENU_TOGGLE) {
        remember_event(TRAY_TOGGLE);
    } else if (item == MENU_QUIT) {
        remember_event(TRAY_QUIT);
    }
}

/* Event(id, event, data, timestamp): only "clicked" does something. */
static int on_event(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    int item = MENU_ROOT;
    const char *event = "";
    const int result = sd_bus_message_read(message, "is", &item, &event);
    if (result < 0) {
        return result;
    }
    if (strcmp(event, "clicked") == 0) {
        menu_clicked(item);
    }
    return sd_bus_reply_method_return(message, "");
}

/* EventGroup(events) -> id errors: each event as Event would take it. */
static int on_event_group(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    int result = sd_bus_message_enter_container(message, 'a', "(isvu)");
    while (result > 0) {
        result = sd_bus_message_enter_container(message, 'r', "isvu");
        if (result > 0) {
            int item = MENU_ROOT;
            const char *event = "";
            result = sd_bus_message_read(message, "is", &item, &event);
            if (result >= 0 && strcmp(event, "clicked") == 0) {
                menu_clicked(item);
            }
            if (result >= 0) {
                result = sd_bus_message_skip(message, "vu");
            }
            if (result >= 0) {
                result = sd_bus_message_exit_container(message);
            }
            result = result >= 0 ? 1 : result;
        }
    }
    return result < 0 ? result : sd_bus_reply_method_return(message, "ai", 0);
}

/* The menu never changes, so nothing needs updating before it shows. */
static int on_about_to_show(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    return sd_bus_reply_method_return(message, "b", 0);
}

static int on_about_to_show_group(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    return sd_bus_reply_method_return(message, "aiai", 0, 0);
}

/* GetProperty(id, name) -> v: the label (or type) the layout gives. */
static int on_get_property(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    int item = MENU_ROOT;
    const char *name = "";
    const int result = sd_bus_message_read(message, "is", &item, &name);
    if (result < 0) {
        return result;
    }
    const char *label = item == MENU_TOGGLE ? "Show / hide window"
                        : item == MENU_QUIT ? "Quit"
                                            : "";
    return sd_bus_reply_method_return(message, "v", "s", strcmp(name, "label") == 0 ? label : "");
}

/* The dbusmenu's own properties. The parameters are sd_bus_property_get_t's
 * (docs/exceptions.md). */
// NOLINTNEXTLINE(bugprone-easily-swappable-parameters)
static int get_menu_property(sd_bus *connection, const char *path, const char *interface,
                             const char *property, sd_bus_message *reply, void *userdata,
                             sd_bus_error *error) {
    (void)connection;
    (void)path;
    (void)interface;
    (void)userdata;
    (void)error;
    if (strcmp(property, "Version") == 0) {
        return sd_bus_message_append(reply, "u", (uint32_t)DBUSMENU_VERSION);
    }
    if (strcmp(property, "IconThemePath") == 0) {
        return sd_bus_message_append(reply, "as", 0);
    }
    return sd_bus_message_append(reply, "s",
                                 strcmp(property, "TextDirection") == 0 ? "ltr" : "normal");
}

static const sd_bus_vtable MENU_VTABLE[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_PROPERTY("Version", "u", get_menu_property, 0, 0),
    SD_BUS_PROPERTY("TextDirection", "s", get_menu_property, 0, 0),
    SD_BUS_PROPERTY("Status", "s", get_menu_property, 0, 0),
    SD_BUS_PROPERTY("IconThemePath", "as", get_menu_property, 0, 0),
    SD_BUS_METHOD("GetLayout", "iias", "u(ia{sv}av)", on_get_layout, 0),
    SD_BUS_METHOD("GetGroupProperties", "aias", "a(ia{sv})", on_get_group_properties, 0),
    SD_BUS_METHOD("GetProperty", "is", "v", on_get_property, 0),
    SD_BUS_METHOD("Event", "isvu", "", on_event, 0),
    SD_BUS_METHOD("EventGroup", "a(isvu)", "ai", on_event_group, 0),
    SD_BUS_METHOD("AboutToShow", "i", "b", on_about_to_show, 0),
    SD_BUS_METHOD("AboutToShowGroup", "ai", "aiai", on_about_to_show_group, 0),
    SD_BUS_SIGNAL("ItemsPropertiesUpdated", "a(ia{sv})a(ias)", 0),
    SD_BUS_SIGNAL("LayoutUpdated", "ui", 0),
    SD_BUS_SIGNAL("ItemActivationRequested", "iu", 0),
    SD_BUS_VTABLE_END};

static bool register_with_watcher(void) {
    sd_bus_error error = SD_BUS_ERROR_NULL;
    const int result =
        sd_bus_call_method(bus, WATCHER, WATCHER_PATH, WATCHER, "RegisterStatusNotifierItem",
                           &error, NULL, "s", service_name);
    sd_bus_error_free(&error);
    return result >= 0;
}

/* A tray host that starts (or restarts, as plasmashell can) gets the icon
 * again. Asynchronous: this runs inside sd_bus_process. */
static int on_name_owner_changed(sd_bus_message *message, void *userdata, sd_bus_error *error) {
    (void)userdata;
    (void)error;
    const char *name = "";
    const char *old_owner = "";
    const char *new_owner = "";
    if (sd_bus_message_read(message, "sss", &name, &old_owner, &new_owner) >= 0 &&
        strcmp(name, WATCHER) == 0 && new_owner[0] != '\0') {
        sd_bus_call_method_async(bus, NULL, WATCHER, WATCHER_PATH, WATCHER,
                                 "RegisterStatusNotifierItem", NULL, NULL, "s", service_name);
    }
    return 0;
}

static bool export_objects(void) {
    return sd_bus_request_name(bus, service_name, 0) >= 0 &&
           sd_bus_add_object_vtable(bus, NULL, ITEM_PATH, ITEM_INTERFACE, ITEM_VTABLE, NULL) >= 0 &&
           sd_bus_add_object_vtable(bus, NULL, MENU_PATH, MENU_INTERFACE, MENU_VTABLE, NULL) >= 0 &&
           sd_bus_match_signal(bus, NULL, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                               "org.freedesktop.DBus", "NameOwnerChanged", on_name_owner_changed,
                               NULL) >= 0;
}

int tray_open(const char *title) {
    if (bus != NULL || sd_bus_open_user(&bus) < 0) {
        return bus != NULL ? 1 : 0;
    }
    snprintf(service_name, sizeof service_name, "org.kde.StatusNotifierItem-%ld-1", (long)getpid());
    copy_text(title_text, title);
    copy_text(progress_text, "");
    progress_permille = 0;
    draw_icon();
    if (!export_objects() || !register_with_watcher()) {
        tray_close();
        return 0;
    }
    atomic_store(&bus_fd, sd_bus_get_fd(bus));
    return 1;
}

void tray_show_progress(const char *label, int permille) {
    if (bus == NULL || (permille == progress_permille && strcmp(label, progress_text) == 0)) {
        return;
    }
    copy_text(progress_text, label);
    progress_permille = permille;
    draw_icon();
    sd_bus_emit_signal(bus, ITEM_PATH, ITEM_INTERFACE, "NewIcon", "");
    sd_bus_emit_signal(bus, ITEM_PATH, ITEM_INTERFACE, "NewToolTip", "");
    sd_bus_flush(bus);
}

int tray_next_event(void) {
    if (bus == NULL) {
        return TRAY_NONE;
    }
    while (sd_bus_process(bus, NULL) > 0) {
    }
    const int event = pending_event;
    pending_event = TRAY_NONE;
    return event;
}

int tray_bus_fd(void) {
    return atomic_load(&bus_fd);
}

void tray_close(void) {
    atomic_store(&bus_fd, -1);
    bus = sd_bus_flush_close_unref(bus);
    pending_event = TRAY_NONE;
}
