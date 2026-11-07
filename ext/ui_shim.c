/*
 * See ui_shim.h. Signatures of every raylib call used here are copied in
 * docs/raylib-notes.md from the raylib.h this is built against.
 */
#include "ui_shim.h"

#include <raylib.h>

/* raygui is header-only: this is the one translation unit that holds its
 * implementation. Included as a system header (docs/raylib-notes.md). */
#define RAYGUI_IMPLEMENTATION
#include <raygui.h>

enum {
    FONT_SLOTS = 3,
    CHECKBOX_BORDER_WIDTH = 2,
    CHECKBOX_CHECK_PADDING = 3,
    MIN_WINDOW_WIDTH = 200,
    MIN_WINDOW_HEIGHT = 120,
    /* Low on purpose: idle CPU stays light, and file polling still runs. */
    TARGET_FPS = 10,
    RED_SHIFT = 24,
    GREEN_SHIFT = 16,
    BLUE_SHIFT = 8,
    CHANNEL_MASK = 0xFF,
    MAX_CODEPOINTS = 512
};

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
    return count;
}

static void release_font(int slot) {
    if (font_owned[slot]) {
        UnloadFont(fonts[slot]);
        font_owned[slot] = false;
    }
}

void ui_open_window(int width, int height, const char *title) {
    SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_MSAA_4X_HINT);
    /* Errors only: on Wayland, InitWindow's attempt to centre the window logs
     * GLFW "window position" warnings that are expected there (the compositor
     * places windows), and font problems are shown in the window instead. */
    SetTraceLogLevel(LOG_ERROR);
    InitWindow(width, height, title);
    SetWindowMinSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
    SetTargetFPS(TARGET_FPS);
    /* Escape must not quit: only the window's close button does. */
    SetExitKey(KEY_NULL);
    for (int slot = 0; slot < FONT_SLOTS; slot++) {
        fonts[slot] = GetFontDefault();
    }
}

int ui_window_ready(void) {
    return IsWindowReady() ? 1 : 0;
}

int ui_window_should_close(void) {
    return WindowShouldClose() ? 1 : 0;
}

void ui_close_window(void) {
    for (int slot = 0; slot < FONT_SLOTS; slot++) {
        release_font(slot);
    }
    CloseWindow();
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

void ui_end_frame(void) {
    EndDrawing();
}

void ui_load_font(int slot, const char *path, int pixel_size) {
    static int codepoints[MAX_CODEPOINTS];
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

void ui_draw_rect(float left, float top, float width, float height, uint32_t rgba) {
    const Rectangle rect = {left, top, width, height};
    DrawRectangleRec(rect, color_from(rgba));
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

/* raygui flips its own copy of the state; the caller only needs to know a
 * click happened, because the file (not this box) is the source of truth. */
int ui_checkbox(float left, float top, float size, int checked) {
    const Rectangle bounds = {left, top, size, size};
    bool state = checked != 0;
    return GuiCheckBox(bounds, NULL, &state) == RESULT_CHANGED ? 1 : 0;
}

float ui_text_width(int slot, const char *text, float size) {
    return MeasureTextEx(fonts[checked_slot(slot)], text, size, GLYPH_SPACING).x;
}

void ui_draw_text(int slot, const char *text, float left, float top, float size, uint32_t rgba) {
    const Vector2 position = {left, top};
    DrawTextEx(fonts[checked_slot(slot)], text, position, size, GLYPH_SPACING, color_from(rgba));
}
