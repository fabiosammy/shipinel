# Exceptions

Every place a check is relaxed, and why. CLAUDE.md requires each one to be
listed here. Thresholds (RuboCop Metrics, Flog, Flay, RubyCritic grades,
coverage) are never relaxed.

## RuboCop

| Cop | Where | Why |
|---|---|---|
| `Style/ComparableBetween` | disabled in `.rubocop.yml` | It asks for `x.between?(lo, hi)`. Under Spinel that pulls the Comparable builtins (`builtins/comparable.rb`) into the program, and they report six widen warnings, which this project treats as errors. `x >= lo && x <= hi` compiles cleanly and reads the same. |
| `Naming/RescuedExceptionsVariableName` | `PreferredName: error` | A naming choice, not a relaxation: RuboCop's default `e` is what Reek's `UncommunicativeVariableName` rejects, so both tools now require `error`. |
| `Layout/LeadingCommentSpace` | `AllowRBSInlineAnnotation: true` | Not a relaxation of the rule's intent: `#: T` is the inline RBS syntax Spinel and rbs-inline read, and it has no space by definition. |

## Reek

| Smell | Where | Why |
|---|---|---|
| `UtilityFunction` | `Shipinel::Screen`, `Shipinel::FontShim` and `Shipinel::Fontconfig` only (`.reek.yml`) | These are adapters over something outside Ruby: the first two make single calls into `ext/ui_shim.c`, which holds the window and font state; `Fontconfig` runs `fc-match`. They exist so `App`, `FontSet` and `FontLocator` can take fakes in CRuby tests; giving them state of their own would duplicate the outside side. Every other class keeps the smell on. |

## Spinel widen warnings

None. `rake spinel_widen` fails on any warning.

## clang-tidy / cppcheck

| Check | Where | Why |
|---|---|---|
| `bugprone-easily-swappable-parameters` | `IgnoredParameterNames` adds the geometry names `left`, `top`, `width`, `height`, `size` (`.clang-tidy`) | Structs cannot cross Spinel's FFI, so `ui_draw_text`, `ui_draw_rect` and `ui_checkbox` take positions and sizes as separate floats in raylib's order. Their only callers are `Screen` methods that unpack a Ruby `Point` or `Rect`, so a swap cannot happen at a call site that people write. The check stays on for every other parameter name. |

cppcheck: none.
