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
| `FeatureEnvy`, `DuplicateMethodCall` | `Shipinel::Layout#place_kind` (both) and `Shipinel::Painter#draw` (`FeatureEnvy`) only (`.reek.yml`) | The method dispatches on the block's kind with `case`. Spinel refuses to pass a block narrowed by `is_a?` to a method typed with its subclass, so each branch reads its kind's fields (`level`; `depth`, `line_index`, `checked?`; `depth`, `marker`) right there: Reek sees many references to `block`, and `block.depth` in two exclusive branches. |
| `UtilityFunction` | `Shipinel::Screen`, `Shipinel::FontShim` and `Shipinel::Fontconfig` only (`.reek.yml`) | These are adapters over something outside Ruby: the first two make single calls into `ext/ui_shim.c`, which holds the window and font state; `Fontconfig` runs `fc-match`. They exist so `App`, `FontSet` and `FontLocator` can take fakes in CRuby tests; giving them state of their own would duplicate the outside side. Every other class keeps the smell on. |

## Spinel widen warnings

None. `rake spinel_widen` fails on any warning.

## clang-tidy / cppcheck

| Check | Where | Why |
|---|---|---|
| `bugprone-reserved-identifier` | the `#define _POSIX_C_SOURCE 200809L` line at the top of `ext/ui_shim.c` only (`NOLINTNEXTLINE`) | Frame pacing sleeps with `clock_nanosleep`, which is POSIX, not C11, so under `-std=c11` the C library declares it only when this feature-test macro is defined first. The name is reserved precisely because the C library reads it; POSIX tells programs to define it. The check stays on for every other identifier. |
| `bugprone-easily-swappable-parameters` | `IgnoredParameterNames` adds the geometry names `left`, `top`, `width`, `height`, `size` (`.clang-tidy`) | Structs cannot cross Spinel's FFI, so `ui_draw_text`, `ui_draw_rect` and `ui_checkbox` take positions and sizes as separate floats in raylib's order. Their only callers are `Screen` methods that unpack a Ruby `Point` or `Rect`, so a swap cannot happen at a call site that people write. The check stays on for every other parameter name. |

cppcheck: none.
