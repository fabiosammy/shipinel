/*
 * The only C in Shipinel: a thin adapter over raylib for Spinel's FFI.
 * raylib passes Color, Vector2 and Font by value, which Spinel FFI cannot,
 * so every function here takes scalars and strings only. Colors are
 * 0xRRGGBBAA. Loaded fonts stay in this file as static state, named by a
 * small slot number. No application logic lives here.
 *
 * Yes/no values are int (1 or 0), not bool: Spinel's FFI `:bool` is a C
 * int, and a C bool would only use the low byte of the register.
 */
#ifndef SHIPINEL_UI_SHIM_H
#define SHIPINEL_UI_SHIM_H

#include <stdint.h>

/* Opens the resizable window and sets the idle frame rate. */
void ui_open_window(int width, int height, const char *title);
/* 1 when the window (and its OpenGL context) opened. */
int ui_window_ready(void);
int ui_window_should_close(void);
/* Unloads every font, then closes the window. */
void ui_close_window(void);
int ui_screen_width(void);
int ui_screen_height(void);

void ui_begin_frame(uint32_t background_rgba);
void ui_end_frame(void);

/* Characters to load into every font after the base set (ASCII, Latin-1
 * Supplement, Latin Extended-A, dashes, quotes, bullet, ellipsis): the
 * ones a document uses beyond it. Kept until the next call. */
void ui_set_extra_codepoints(const int64_t *codepoints, int count);
/* Loads a TTF/OTF into a slot with the base and extra characters it has.
 * If it cannot be loaded, the slot holds raylib's built-in font, which has
 * no accented letters. */
void ui_load_font(int slot, const char *path, int pixel_size);
/* 1 when the slot holds a font loaded from a file. */
int ui_font_loaded(int slot);
/* Which loaded fonts can draw the character: bit n set for slot n. */
int ui_glyph_slots(int codepoint);
float ui_text_width(int slot, const char *text, float size);
void ui_draw_rect(float left, float top, float width, float height, uint32_t rgba);
/* Where the mouse is relative to the rectangle: 0 away, 1 over it, 2 the
 * left button was released over it this frame (a click). */
int ui_pointer_on(float left, float top, float width, float height);
/* 1: the pointing-hand cursor (over something clickable); 0: the default. */
void ui_set_hand_cursor(int hand);
/* The mouse position in the window, in pixels. */
int ui_mouse_x(void);
int ui_mouse_y(void);
/* The left button: bit 1 held down, bit 2 pressed this frame. */
int ui_mouse_buttons(void);
/* How far the mouse wheel moved this frame; positive is away from the user. */
float ui_wheel_move(void);
/* Colors of every checkbox: its border, its border under the mouse, and
 * the check mark. */
void ui_style_checkbox(uint32_t border_rgba, uint32_t hover_rgba, uint32_t check_rgba);
/* Draws a checkbox (with its hover look); clicks come from ui_pointer_on. */
void ui_draw_checkbox(float left, float top, float size, int checked);
void ui_draw_text(int slot, const char *text, float left, float top, float size, uint32_t rgba);

#endif
