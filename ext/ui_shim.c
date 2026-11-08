/*
 * See ui_shim.h. Signatures of every raylib call used here are copied in
 * docs/raylib-notes.md from the raylib.h this is built against.
 */
/* clock_nanosleep is POSIX, not C11. This feature-test macro is how POSIX
 * asks for it; its name is reserved because the C library reads it
 * (docs/exceptions.md). */
// NOLINTNEXTLINE(bugprone-reserved-identifier)
#define _POSIX_C_SOURCE 200809L

#include "ui_shim.h"

#include <errno.h>
#include <raylib.h>
#include <stdbool.h>
#include <threads.h>
#include <time.h>

/* GLFW is the window layer raylib is built on; the shim calls it only to
 * wake an idle wait and to hear when the window must be drawn again
 * (docs/raylib-notes.md). No GL headers: raylib loads OpenGL itself. */
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

/* raygui is header-only: this is the one translation unit that holds its
 * implementation. Included as a system header (docs/raylib-notes.md). */
#define RAYGUI_IMPLEMENTATION
#include <raygui.h>

enum {
    FONT_SLOTS = 5,
    CHECKBOX_BORDER_WIDTH = 2,
    CHECKBOX_CHECK_PADDING = 3,
    MIN_WINDOW_WIDTH = 200,
    MIN_WINDOW_HEIGHT = 120,
    /* Drawn frames are paced at this rate while the user scrolls or
     * points; idle frames wait for input instead (ui_skip_frame). */
    FRAME_RATE = 60,
    /* How often the waker ends an idle wait, so the file is still polled. */
    WAKES_PER_SECOND = 2,
    RED_SHIFT = 24,
    GREEN_SHIFT = 16,
    BLUE_SHIFT = 8,
    CHANNEL_MASK = 0xFF,
    MAX_CODEPOINTS = 512,
    /* Characters a document may add on top of the base set (arrows, emoji). */
    MAX_EXTRA_CODEPOINTS = 2048,
    /* ui_pointer_on's answers. */
    POINTER_AWAY = 0,
    POINTER_OVER = 1,
    POINTER_CLICKED = 2,
    /* ui_keys_pressed answers in the bits of an int. */
    MAX_WATCHED_KEYS = 30,
    /* ui_mouse_buttons' bits. */
    MOUSE_DOWN = 1,
    MOUSE_PRESSED = 2
};

static const long NANOSECONDS = 1000000000L;

/* No extra space between glyphs: the font's own advance widths apply. */
static const float GLYPH_SPACING = 0.0F;

/* First and last codepoint of each block loaded into every font. */
static const int CODEPOINT_RANGES[][2] = {
    {0x0020, 0x007E}, /* ASCII */
    {0x00A0, 0x00FF}, /* Latin-1 Supplement: ã, ç, é, ... */
    {0x0100, 0x017F}, /* Latin Extended-A */
    {0x2013, 0x2014}, /* en and em dash */
    {0x2018, 0x201D}, /* curly quotes */
    {0x2022, 0x2022}, /* bullet */
    {0x2026, 0x2026}, /* ellipsis */
};

static Font fonts[FONT_SLOTS];
static bool font_owned[FONT_SLOTS];
/* Set by ui_set_extra_codepoints, used by every ui_load_font after it. */
static int extra_codepoints[MAX_EXTRA_CODEPOINTS];
static int extra_count = 0;
/* Frame pacing (ui_end_frame): how long a frame lasts, and when the next
 * one is due on the monotonic clock. */
static const long FRAME_NANOSECONDS = NANOSECONDS / FRAME_RATE;
static struct timespec next_frame;

/* The waker thread posts an empty GLFW event every half second while the
 * window is open; it stops when waker_running turns false under the lock. */
static thrd_t waker;
static mtx_t waker_lock;
static cnd_t waker_stop;
static bool waker_running = false;
/* Set by GLFW when the window system needs the window drawn again (an X11
 * window uncovered without a compositor); read by ui_skip_frame. */
static bool redraw_requested = false;

static Color color_from(uint32_t rgba) {
    Color color = {
        (unsigned char)((rgba >> RED_SHIFT) & CHANNEL_MASK),
        (unsigned char)((rgba >> GREEN_SHIFT) & CHANNEL_MASK),
        (unsigned char)((rgba >> BLUE_SHIFT) & CHANNEL_MASK),
        (unsigned char)(rgba & CHANNEL_MASK),
    };
    return color;
}

/* An unknown slot uses slot 0 rather than reading out of bounds. */
static int checked_slot(int slot) {
    return (slot >= 0 && slot < FONT_SLOTS) ? slot : 0;
}

/* The base ranges, then the extra codepoints. */
static int fill_codepoints(int *codepoints) {
    int count = 0;
    const int ranges = (int)(sizeof CODEPOINT_RANGES / sizeof CODEPOINT_RANGES[0]);
    for (int range = 0; range < ranges; range++) {
        for (int codepoint = CODEPOINT_RANGES[range][0];
             codepoint <= CODEPOINT_RANGES[range][1] && count < MAX_CODEPOINTS; codepoint++) {
            codepoints[count] = codepoint;
            count++;
        }
    }
    for (int extra = 0; extra < extra_count; extra++) {
        codepoints[count] = extra_codepoints[extra];
        count++;
    }
    return count;
}

static void release_font(int slot) {
    if (font_owned[slot]) {
        UnloadFont(fonts[slot]);
        font_owned[slot] = false;
    }
}

static void on_window_refresh(GLFWwindow *window) {
    (void)window;
    redraw_requested = true;
}

/* Sleeps in half-second steps until told to stop, posting an empty event
 * after each: glfwPostEmptyEvent is the one GLFW call any thread may make,
 * and it ends the main thread's glfwWaitEvents. */
static int wake_loop(void *unused) {
    (void)unused;
    mtx_lock(&waker_lock);
    while (waker_running) {
        struct timespec until;
        timespec_get(&until, TIME_UTC);
        until.tv_nsec += NANOSECONDS / WAKES_PER_SECOND;
        if (until.tv_nsec >= NANOSECONDS) {
            until.tv_sec += 1;
            until.tv_nsec -= NANOSECONDS;
        }
        if (cnd_timedwait(&waker_stop, &waker_lock, &until) == thrd_timedout) {
            glfwPostEmptyEvent();
        }
    }
    mtx_unlock(&waker_lock);
    return 0;
}

/* Without the waker an idle wait could last forever, so ui_skip_frame
 * falls back to sleeping and polling when it cannot start. */
static void start_waker(void) {
    if (mtx_init(&waker_lock, mtx_plain) != thrd_success) {
        return;
    }
    if (cnd_init(&waker_stop) != thrd_success) {
        mtx_destroy(&waker_lock);
        return;
    }
    waker_running = true;
    if (thrd_create(&waker, wake_loop, NULL) != thrd_success) {
        waker_running = false;
        cnd_destroy(&waker_stop);
        mtx_destroy(&waker_lock);
    }
}

static void stop_waker(void) {
    if (!waker_running) {
        return;
    }
    mtx_lock(&waker_lock);
    waker_running = false;
    cnd_signal(&waker_stop);
    mtx_unlock(&waker_lock);
    thrd_join(waker, NULL);
    cnd_destroy(&waker_stop);
    mtx_destroy(&waker_lock);
}

void ui_open_window(int width, int height, const char *title) {
    /* No MSAA: everything drawn is text or an axis-aligned rectangle, and
     * multisampling made each frame several times dearer to render. */
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    /* Errors only: on Wayland, InitWindow's attempt to centre the window logs
     * GLFW "window position" warnings that are expected there (the compositor
     * places windows), and font problems are shown in the window instead. */
    SetTraceLogLevel(LOG_ERROR);
    InitWindow(width, height, title);
    SetWindowMinSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
    /* No SetTargetFPS: raylib then never waits, and ui_end_frame paces the
     * frames itself (see wait_for_next_frame). */
    clock_gettime(CLOCK_MONOTONIC, &next_frame);
    /* Escape must not quit: only the window's close button does. */
    SetExitKey(KEY_NULL);
    for (int slot = 0; slot < FONT_SLOTS; slot++) {
        fonts[slot] = GetFontDefault();
    }
    if (IsWindowReady()) {
        glfwSetWindowRefreshCallback((GLFWwindow *)GetWindowHandle(), on_window_refresh);
        start_waker();
    }
}

int ui_window_ready(void) {
    return IsWindowReady() ? 1 : 0;
}

int ui_window_should_close(void) {
    return WindowShouldClose() ? 1 : 0;
}

/* The waker stops first: it must not post to GLFW once CloseWindow has
 * shut GLFW down. */
void ui_close_window(void) {
    stop_waker();
    for (int slot = 0; slot < FONT_SLOTS; slot++) {
        release_font(slot);
    }
    CloseWindow();
}

/* Only X11 lets a program know and set its window's position; on Wayland
 * the compositor alone places windows (and GLFW reports an error). */
int ui_window_placeable(void) {
    return glfwGetPlatform() == GLFW_PLATFORM_WAYLAND ? 0 : 1;
}

int ui_window_x(void) {
    return (int)GetWindowPosition().x;
}

int ui_window_y(void) {
    return (int)GetWindowPosition().y;
}

void ui_move_window(int left, int top) {
    if (ui_window_placeable()) {
        SetWindowPosition(left, top);
    }
}

int ui_screen_width(void) {
    return GetScreenWidth();
}

int ui_screen_height(void) {
    return GetScreenHeight();
}

void ui_begin_frame(uint32_t background_rgba) {
    BeginDrawing();
    ClearBackground(color_from(background_rgba));
}

/* raylib's own frame wait (SetTargetFPS) spins on the CPU for the last 5%
 * of every frame; this sleeps the whole time instead. A frame that ran
 * late starts the next one from now rather than rushing to catch up. */
static void wait_for_next_frame(void) {
    next_frame.tv_nsec += FRAME_NANOSECONDS;
    if (next_frame.tv_nsec >= NANOSECONDS) {
        next_frame.tv_sec += next_frame.tv_nsec / NANOSECONDS;
        next_frame.tv_nsec %= NANOSECONDS;
    }
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (now.tv_sec > next_frame.tv_sec ||
        (now.tv_sec == next_frame.tv_sec && now.tv_nsec > next_frame.tv_nsec)) {
        next_frame = now;
        return;
    }
    while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next_frame, NULL) == EINTR) {
    }
}

/* The wait comes before EndDrawing, which polls input: the next frame then
 * acts on input from right after the sleep, not from before it. */
void ui_end_frame(void) {
    wait_for_next_frame();
    EndDrawing();
}

/* A frame that draws nothing: no BeginDrawing, no buffer swap, so the
 * window keeps the last frame shown. It sleeps until input arrives or the
 * waker posts its event (raylib's event waiting makes PollInputEvents call
 * glfwWaitEvents after saving the previous input state, so a click that
 * wakes it is still seen as pressed). Pacing then restarts from now.
 * Returns 1 when the window system asked for the window to be drawn. */
int ui_skip_frame(void) {
    if (waker_running) {
        EnableEventWaiting();
        PollInputEvents();
        DisableEventWaiting();
        clock_gettime(CLOCK_MONOTONIC, &next_frame);
    } else {
        wait_for_next_frame();
        PollInputEvents();
    }
    const bool redraw = redraw_requested;
    redraw_requested = false;
    return redraw ? 1 : 0;
}

void ui_set_extra_codepoints(const int64_t *codepoints, int count) {
    extra_count = 0;
    for (int index = 0; index < count && index < MAX_EXTRA_CODEPOINTS; index++) {
        extra_codepoints[index] = (int)codepoints[index];
        extra_count++;
    }
}

void ui_load_font(int slot, const char *path, int pixel_size) {
    static int codepoints[MAX_CODEPOINTS + MAX_EXTRA_CODEPOINTS];
    const int count = fill_codepoints(codepoints);
    const int target = checked_slot(slot);
    const Font loaded = LoadFontEx(path, pixel_size, codepoints, count);
    release_font(target);
    /* raylib does not fail on an unreadable font: it returns its built-in
     * one, which is valid. Telling them apart takes the texture id. */
    if (!IsFontValid(loaded) || loaded.texture.id == GetFontDefault().texture.id) {
        fonts[target] = GetFontDefault();
        return;
    }
    SetTextureFilter(loaded.texture, TEXTURE_FILTER_BILINEAR);
    fonts[target] = loaded;
    font_owned[target] = true;
}

int ui_font_loaded(int slot) {
    return font_owned[checked_slot(slot)] ? 1 : 0;
}

/* raylib loads only the glyphs a font really has (LoadFontData skips
 * missing ones), so a loaded glyph is a drawable one. */
static bool slot_has_glyph(int slot, int codepoint) {
    if (!font_owned[slot]) {
        return false;
    }
    for (int glyph = 0; glyph < fonts[slot].glyphCount; glyph++) {
        if (fonts[slot].glyphs[glyph].value == codepoint) {
            return true;
        }
    }
    return false;
}

int ui_glyph_slots(int codepoint) {
    int slots = 0;
    for (int slot = 0; slot < FONT_SLOTS; slot++) {
        if (slot_has_glyph(slot, codepoint)) {
            slots |= 1 << slot;
        }
    }
    return slots;
}

void ui_draw_rect(float left, float top, float width, float height, uint32_t rgba) {
    const Rectangle rect = {left, top, width, height};
    DrawRectangleRec(rect, color_from(rgba));
}

int ui_pointer_on(float left, float top, float width, float height) {
    const Rectangle area = {left, top, width, height};
    if (!CheckCollisionPointRec(GetMousePosition(), area)) {
        return POINTER_AWAY;
    }
    return IsMouseButtonReleased(MOUSE_BUTTON_LEFT) ? POINTER_CLICKED : POINTER_OVER;
}

/* raylib's SetMouseCursor creates a new GLFW cursor on every call and never
 * frees it, so the cursor is only set when it changes. */
void ui_set_hand_cursor(int hand) {
    static int current = 0;
    const int wanted = hand != 0 ? 1 : 0;
    if (wanted != current) {
        SetMouseCursor(wanted != 0 ? MOUSE_CURSOR_POINTING_HAND : MOUSE_CURSOR_DEFAULT);
        current = wanted;
    }
}

int ui_mouse_x(void) {
    return GetMouseX();
}

int ui_mouse_y(void) {
    return GetMouseY();
}

int ui_mouse_buttons(void) {
    return (IsMouseButtonDown(MOUSE_BUTTON_LEFT) ? MOUSE_DOWN : 0) |
           (IsMouseButtonPressed(MOUSE_BUTTON_LEFT) ? MOUSE_PRESSED : 0);
}

int ui_keys_pressed(const int64_t *keys, int count) {
    int pressed = 0;
    for (int index = 0; index < count && index < MAX_WATCHED_KEYS; index++) {
        const int key = (int)keys[index];
        if (IsKeyPressed(key) || IsKeyPressedRepeat(key)) {
            pressed |= 1 << index;
        }
    }
    return pressed;
}

float ui_wheel_move(void) {
    return GetMouseWheelMove();
}

/* raygui reads colors as ints in the same 0xRRGGBBAA layout. */
void ui_style_checkbox(uint32_t border_rgba, uint32_t hover_rgba, uint32_t check_rgba) {
    GuiSetStyle(CHECKBOX, BORDER_COLOR_NORMAL, (int)border_rgba);
    GuiSetStyle(CHECKBOX, BORDER_COLOR_FOCUSED, (int)hover_rgba);
    GuiSetStyle(CHECKBOX, BORDER_COLOR_PRESSED, (int)hover_rgba);
    GuiSetStyle(CHECKBOX, TEXT_COLOR_NORMAL, (int)check_rgba);
    GuiSetStyle(CHECKBOX, TEXT_COLOR_FOCUSED, (int)check_rgba);
    GuiSetStyle(CHECKBOX, TEXT_COLOR_PRESSED, (int)check_rgba);
    GuiSetStyle(CHECKBOX, BORDER_WIDTH, CHECKBOX_BORDER_WIDTH);
    GuiSetStyle(CHECKBOX, CHECK_PADDING, CHECKBOX_CHECK_PADDING);
}

/* Draws only: clicks come from ui_pointer_on, as for links. raygui flips
 * its own copy of the state, which is dropped: the file, not this box, is
 * the source of truth. */
void ui_draw_checkbox(float left, float top, float size, int checked) {
    const Rectangle bounds = {left, top, size, size};
    bool state = checked != 0;
    (void)GuiCheckBox(bounds, NULL, &state);
}

float ui_text_width(int slot, const char *text, float size) {
    return MeasureTextEx(fonts[checked_slot(slot)], text, size, GLYPH_SPACING).x;
}

void ui_draw_text(int slot, const char *text, float left, float top, float size, uint32_t rgba) {
    const Vector2 position = {left, top};
    DrawTextEx(fonts[checked_slot(slot)], text, position, size, GLYPH_SPACING, color_from(rgba));
}
