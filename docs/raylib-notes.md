# raylib / raygui notes

Exact signatures copied from the headers we link against. Do not add a call to
`ext/ui_shim.c` without first copying its signature here.

## Versions and sources

| Library | Version | Where it comes from |
|---|---|---|
| raylib | **6.2** (`RAYLIB_VERSION "6.2"`, `raylib.h:92`) | nixpkgs `pkgs/by-name/ra/raylib`, `platform = "Desktop"`, `USE_EXTERNAL_GLFW=ON` |
| raygui | **5.0** (`RAYGUI_VERSION "5.0"`, `raygui.h:358`) | nixpkgs `pkgs/by-name/ra/raygui` (installs `include/raygui.h`) |
| GLFW | 3.4 | nixpkgs `glfw3`, built with Wayland **and** X11 support |

raygui is in nixpkgs, so **nothing is vendored** and `ext/VENDORED.md` is not
needed. The headers were read from the upstream tags these nixpkgs packages
pin (`raysan5/raylib@6.2`, `raysan5/raygui@5.0`). Re-check them against
`$(nix eval nixpkgs#raylib.outPath)/include/raylib.h` once the flake exists.

raygui is header-only: exactly one translation unit defines
`RAYGUI_IMPLEMENTATION` before including it. That is `ext/ui_shim.c`. The
raygui implementation does not compile cleanly under
`-Wconversion -Werror`, so it must be included as a **system header**
(`-isystem`; Nix's `NIX_CFLAGS_COMPILE` already passes store include dirs that
way). Warnings inside it are then suppressed, and our own code stays under the
strict flags.

## Structs (passed by value by raylib, so built inside the shim)

```c
// raylib.h:216
typedef struct Vector2 {
    float x;                // Vector x component
    float y;                // Vector y component
} Vector2;

// raylib.h:248
typedef struct Color {
    unsigned char r;        // Color red value
    unsigned char g;        // Color green value
    unsigned char b;        // Color blue value
    unsigned char a;        // Color alpha value
} Color;

// raylib.h:256
typedef struct Rectangle {
    float x;                // Rectangle top-left corner position x
    float y;                // Rectangle top-left corner position y
    float width;            // Rectangle width
    float height;           // Rectangle height
} Rectangle;

// raylib.h:273
typedef struct Texture {
    unsigned int id;        // OpenGL texture id
    int width;              // Texture base width
    int height;             // Texture base height
    int mipmaps;            // Mipmap levels, 1 by default
    int format;             // Data format (PixelFormat type)
} Texture;                  // Texture2D is the same type

// raylib.h:317
typedef struct Font {
    int baseSize;           // Base size (default chars height)
    int glyphCount;         // Number of glyph characters
    int glyphPadding;       // Padding around the glyph characters
    Texture2D texture;      // Texture atlas containing the glyphs
    Rectangle *recs;        // Rectangles in texture for the glyphs
    GlyphInfo *glyphs;      // Glyphs info data
} Font;
```

The shim takes colors as one `uint32_t` `0xRRGGBBAA`, so the Ruby theme holds
plain Integers and C unpacks them.

## Window and frame

```c
RLAPI void InitWindow(int width, int height, const char *title);  // raylib.h:988
RLAPI void CloseWindow(void);                                     // raylib.h:989
RLAPI bool WindowShouldClose(void);                               // raylib.h:990
RLAPI bool IsWindowReady(void);                                   // raylib.h:991
RLAPI void SetWindowMinSize(int width, int height);               // raylib.h:1011
RLAPI int GetScreenWidth(void);                                   // raylib.h:1017
RLAPI int GetScreenHeight(void);                                  // raylib.h:1018
RLAPI void ClearBackground(Color color);                          // raylib.h:1047
RLAPI void BeginDrawing(void);                                    // raylib.h:1048
RLAPI void EndDrawing(void);                                      // raylib.h:1049
RLAPI void BeginScissorMode(int x, int y, int width, int height); // raylib.h:1060
RLAPI void EndScissorMode(void);                                  // raylib.h:1061
RLAPI void SetTargetFPS(int fps);                                 // raylib.h:1093
RLAPI void SetConfigFlags(unsigned int flags);                    // raylib.h:1114
RLAPI void SetTraceLogLevel(int logLevel);                        // raylib.h:1118
RLAPI void SetExitKey(int key);                                   // raylib.h:1210
```

- `SetConfigFlags` must be called **before** `InitWindow`.
- `WindowShouldClose` is also true on Escape. We call `SetExitKey(KEY_NULL)`
  so only the window close button quits.
- No `EnableEventWaiting()` (it would block file polling), and no
  `SetTargetFPS`: raylib's frame wait (`WaitTime`, rcore.c) sleeps 95% of
  the frame and spins on the CPU for the last 5%
  (`SUPPORT_PARTIALBUSY_WAIT_LOOP`, on by default in config.h). Without a
  target FPS raylib never waits; `ui_end_frame` sleeps until the frame is
  due with POSIX `clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, ...)`,
  then calls `EndDrawing`, which polls input right after the sleep.
- Frames are paced at 60 per second, but an idle frame showing an
  unchanged page is not drawn: `ui_skip_frame` sleeps and calls
  `PollInputEvents` (raylib.h:1103) without `BeginDrawing` or a buffer
  swap, so the window keeps its last picture. `Activity` draws while the
  user is busy and half a second after, when the layout changed, and every
  2 s in case the window system dropped the picture (X11 without a
  compositor).
- Why 60 even when idle: raylib's `MouseButtonCallback`
  (rcore_desktop_glfw.c) only stores the button's latest state, so a press
  and a release that arrive between two polls are both lost. At 10 polls a
  second, quick clicks (30 ms, checked in Xvfb) were missed every time; at
  60 they register. A click shorter than one frame (~16 ms) can still be
  lost; touchpad taps are not, since libinput holds the release back to
  detect tap-and-drag.
- No `FLAG_MSAA_4X_HINT`: the page is text and axis-aligned rectangles,
  which multisampling does not improve, and it made every frame several
  times dearer to render.

## Input

```c
RLAPI bool IsMouseButtonPressed(int button);                  // raylib.h:1226
RLAPI bool IsMouseButtonDown(int button);                     // raylib.h:1227
RLAPI int GetMouseX(void);                                    // raylib.h:1230
RLAPI int GetMouseY(void);                                    // raylib.h:1231
RLAPI float GetMouseWheelMove(void);                          // raylib.h:1237
RLAPI void SetMouseCursor(int cursor);                        // raylib.h:1239
```

`GetMouseX` / `GetMouseY` return `int`, so the shim does not need
`GetMousePosition` (which returns a `Vector2` by value).

## Drawing

```c
RLAPI void DrawLine(int startPosX, int startPosY, int endPosX, int endPosY, Color color);  // raylib.h:1279
RLAPI void DrawRectangle(int posX, int posY, int width, int height, Color color);          // raylib.h:1291
RLAPI void DrawRectangleLines(int posX, int posY, int width, int height, Color color);     // raylib.h:1298
```

## Fonts and text

```c
RLAPI void SetTextureFilter(Texture2D texture, int filter);                                  // raylib.h:1475
RLAPI Font GetFontDefault(void);                                                             // raylib.h:1510
RLAPI Font LoadFontEx(const char *fileName, int fontSize, const int *codepoints, int codepointCount); // raylib.h:1512
RLAPI bool IsFontValid(Font font);                                                           // raylib.h:1515
RLAPI void UnloadFont(Font font);                                                            // raylib.h:1519
RLAPI void DrawTextEx(Font font, const char *text, Vector2 position, float fontSize, float spacing, Color tint); // raylib.h:1525
RLAPI Vector2 MeasureTextEx(Font font, const char *text, float fontSize, float spacing);     // raylib.h:1533
```

- `LoadFontEx` with `codepoints = NULL` loads only the default set (ASCII 32..126),
  which has no accented letters. The shim builds an `int[]` of
  **U+0020..U+007E, U+00A0..U+00FF (Latin-1 Supplement), U+0100..U+017F
  (Latin Extended-A)** plus `…` U+2026 and `–` U+2013, and passes it in. That
  covers "Reunião", "ação" and "é".
- `IsFontValid` (6.x name; 5.0 called it `IsFontReady`) is **not enough** to
  detect a failed load: `LoadFontFromMemory` (rtext.c) logs "Font is not
  supported ... reverted to default font" and returns `GetFontDefault()`,
  which is valid. The shim also compares `texture.id` with the default
  font's. It accepts only the extensions `.ttf` and `.otf`
  (case-insensitive), so a `.ttc` collection, which fontconfig on NixOS may
  rank first, falls back; `Fontconfig` therefore takes the first `.ttf` /
  `.otf` from `fc-match -s`, preferring static fonts (`variable=false`).
- `DrawTextEx` / `MeasureTextEx` take UTF-8 `const char *`, which is what
  Spinel's `:str` passes.
- `MeasureTextEx` returns a `Vector2`; the shim exposes only its `x`
  (`ui_measure_text_width`) as a `float`. Line height is the font size.
- `TEXTURE_FILTER_BILINEAR` keeps scaled glyphs smooth.

## raygui

```c
RAYGUIAPI void GuiSetFont(Font font);                                    // raygui.h:795
RAYGUIAPI void GuiSetStyle(int control, int property, int value);        // raygui.h:799
RAYGUIAPI int GuiGetStyle(int control, int property);                    // raygui.h:800
RAYGUIAPI void GuiLoadStyleDefault(void);                                // raygui.h:805
RAYGUIAPI int GuiCheckBox(Rectangle bounds, const char *text, bool *checked); // raygui.h:841
```

- `GuiCheckBox` flips `*checked` itself and returns `RESULT_CHANGED` (2) on the
  frame it was clicked, `RESULT_NONE` (0) otherwise (`raygui.h:560-562`, body at
  `int GuiCheckBox`). The shim passes a local `bool` set from the task's state,
  ignores the flipped value, and returns `1` when it changed. Ruby then toggles
  the **source line** that the checkbox's draw command carries. The file stays
  the single source of truth.
- `GuiSetStyle` color properties take the color as an `int` in `0xRRGGBBAA`
  form, the same encoding as our theme Integers.

## Constants

| Name | Value | Source |
|---|---|---|
| `FLAG_WINDOW_RESIZABLE` | `0x00000004` | raylib.h:558 |
| `FLAG_WINDOW_HIGHDPI` | `0x00002000` | raylib.h:567 |
| `KEY_NULL` | `0` | raylib.h:590 |
| `MOUSE_BUTTON_LEFT` | `0` | raylib.h:713 |
| `MOUSE_CURSOR_POINTING_HAND` | `4` | raylib.h:728 |
| `LOG_WARNING` | `4` (enum: ALL 0, TRACE 1, DEBUG 2, INFO 3, WARNING 4) | raylib.h:577-584 |
| `TEXTURE_FILTER_BILINEAR` | `1` (POINT is 0) | raylib.h:884-885 |
| raygui `DEFAULT` control | `0` | raygui.h:602 |
| raygui `CHECKBOX` control | `6` | raygui.h:610 |
| `BORDER_COLOR_NORMAL` / `BASE_COLOR_NORMAL` / `TEXT_COLOR_NORMAL` | `0` / `1` / `2` | raygui.h:627-629 |
| `BORDER_COLOR_FOCUSED` / `BASE_COLOR_FOCUSED` / `TEXT_COLOR_FOCUSED` | `3` / `4` / `5` | raygui.h:630-632 |
| `BORDER_COLOR_PRESSED` / `BASE_COLOR_PRESSED` / `TEXT_COLOR_PRESSED` | `6` / `7` / `8` | raygui.h:633-635 |
| `BORDER_WIDTH` | `12` | raygui.h:639 |
| `TEXT_SIZE` / `TEXT_SPACING` | `16` / `17` | raygui.h:663-664 |
| `BACKGROUND_COLOR` | `19` | raygui.h:666 |
| `CHECK_PADDING` (CHECKBOX property) | `16` | raygui.h:714 |

These constants are used **inside the C shim**, which includes the real
headers, so they come from the headers rather than being copied into Ruby. Ruby
sees none of them.

## The shim's API (ext/ui_shim.h)

What Ruby can call, all scalars and strings (Spinel FFI types in
`lib/shipinel/ui.rb`, Steep types in `sig/ui.rbs`):

| Function | Wraps |
|---|---|
| `void ui_open_window(int, int, const char *)` | `SetConfigFlags(RESIZABLE)`, `SetTraceLogLevel(LOG_ERROR)` (Wayland logs expected "window position" warnings), `InitWindow`, `SetWindowMinSize(200, 120)`, `SetExitKey(KEY_NULL)`, starts frame pacing (60 per second) |
| `void ui_skip_frame(void)` | waits for the frame like `ui_end_frame`, then `PollInputEvents` only: nothing drawn, no swap |
| `int ui_window_ready(void)` | `IsWindowReady` |
| `int ui_window_should_close(void)` | `WindowShouldClose` |
| `void ui_close_window(void)` | `UnloadFont` for each loaded slot, `CloseWindow` |
| `int ui_screen_width(void)`, `int ui_screen_height(void)` | `GetScreenWidth`, `GetScreenHeight` |
| `void ui_begin_frame(uint32_t)`, `void ui_end_frame(void)` | `BeginDrawing` + `ClearBackground`, `EndDrawing` |
| `void ui_load_font(int slot, const char *, int)` | `LoadFontEx` with the codepoint ranges above, `IsFontValid`, `SetTextureFilter(BILINEAR)`; falls back to `GetFontDefault` |
| `int ui_font_loaded(int slot)` | whether the slot holds a file font |
| `float ui_text_width(int, const char *, float)` | `MeasureTextEx(...).x`, spacing 0 |
| `void ui_draw_text(int, const char *, float, float, float, uint32_t)` | `DrawTextEx`, spacing 0 |
| `void ui_draw_rect(float, float, float, float, uint32_t)` | `DrawRectangleRec` |
| `float ui_wheel_move(void)` | `GetMouseWheelMove` |
| `int ui_mouse_x(void)`, `int ui_mouse_y(void)` | `GetMouseX`, `GetMouseY`: the scrollbar's pointer position |
| `int ui_mouse_buttons(void)` | bit 1 `IsMouseButtonDown(LEFT)`, bit 2 `IsMouseButtonPressed(LEFT)`: dragging the thumb, paging on the track |
| `void ui_style_checkbox(uint32_t, uint32_t, uint32_t)` | `GuiSetStyle(CHECKBOX, ...)`: border normal; border focused and pressed; check mark (TEXT_COLOR_*) in all states; `BORDER_WIDTH` 2, `CHECK_PADDING` 3 |

| `void ui_set_extra_codepoints(const int64_t *, int)` | kept for every following `ui_load_font`: the document's characters beyond the base set (Ruby `:int_array`) |
| `int ui_glyph_slots(int codepoint)` | bit n set when slot n's glyphs include it (one argument, so nothing to swap) |
| `int ui_pointer_on(float, float, float, float)` | 0 away, 1 over (`CheckCollisionPointRec(GetMousePosition(), ...)`), 2 clicked (also `IsMouseButtonReleased(LEFT)`): the click for links and checkboxes alike |
| `void ui_set_hand_cursor(int)` | `SetMouseCursor(MOUSE_CURSOR_POINTING_HAND / DEFAULT)`, only when it changes |
| `void ui_draw_checkbox(float, float, float, int)` | `GuiCheckBox(bounds, NULL, &copy)`, result ignored: draws with its hover look |

**Cursor.** `SetMouseCursor` (rcore_desktop_glfw.c:1260) calls
`glfwCreateStandardCursor` every time and never destroys the cursor, so the
shim calls it only when the wanted cursor changes. Checked in Xvfb with
XFixes: `hand2` over a link, the default over text.

Yes/no values are `int`, bound in Ruby as FFI `:bool` (a C `int`). Font
slots: 0 body, 1 mono, 2 bold, 3 symbol (emoji).

**Glyph coverage.** `LoadFontData` (rtext.c) keeps only the codepoints the
font file has (`stbtt_FindGlyphIndex(...) > 0`), so after loading, a glyph in
`font.glyphs` is a drawable one; `ui_glyph_slots` relies on that. Colour
emoji fonts (CBDT/CBLC bitmaps, e.g. Noto Color Emoji) have cmap entries but
no outlines stb_truetype can rasterise, so their glyphs would load blank:
the symbol slot asks fontconfig for `color=false` (Noto Emoji, Symbola).

`GuiCheckBox` (raygui.h:2317) toggles on `GUI_BUTTON_RELEASED` inside the
bounds and returns `RESULT_CHANGED` (2, raygui.h:562) on that frame; it
draws the border in `BORDER + state*3` and the check in `TEXT + state*3`.
The shim passes a local copy of the state, so raygui's flip is discarded:
the file is the source of truth, and the next layout shows the result.

Checked in the sandbox (X11 via the host's display, software OpenGL): the
window opens titled `shipinel`, "reuniões", "ação", "Terça" render with
DejaVu Sans, raylib logs nothing at warning level, and the idle window uses
about 5 % of one core at 10 FPS.

Measured again on 2026-11-07 in Xvfb (software OpenGL, so rendering is CPU
time here and GPU time on a desktop), with the 98-line week runbook: idle
CPU went from 24.5 % to 6.4 % of one core after the layout cache, drawing
only what the window shows, dropping MSAA and replacing raylib's spinning
frame wait. Skipping the drawing of unchanged idle frames then brought it
to 0.65 % while polling input 60 times a second. Before, each frame spent about 6.4 ms laying out and drawing
(1,564 width measurements and 1,548 text draws) and raylib spun for the
last 5 ms of every 100 ms frame.

## Wayland

nixpkgs builds raylib against the external GLFW 3.4, and GLFW 3.4 contains
both the Wayland and X11 backends. It picks Wayland when `WAYLAND_DISPLAY`
is set. Checked in the nixpkgs revision flake.lock pins: `glfw3` builds with
wayland, wayland-protocols and libdecor, and patches its `dlopen` names
(`libwayland-client.so.0`, `libdecor-0.so.0`, ...) to absolute store paths,
so the Wayland libraries are found at run time without any wrapper. To
check a build: `ldd result/bin/shipinel | grep -E 'glfw|wayland'`, and
`WAYLAND_DEBUG=1 shipinel plan.md 2>&1 | head` should show `wl_display`
traffic. To force XWayland, run with `WAYLAND_DISPLAY=` unset
(`env -u WAYLAND_DISPLAY shipinel plan.md`). The README will spell this out.
