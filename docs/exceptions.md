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
| `UtilityFunction` | `Shipinel::Screen` only (`.reek.yml`) | `Screen` is the FFI adapter: each method is a single call into `ext/ui_shim.c`, which holds the window and font state. The class exists so `App` can take a fake screen in CRuby tests; giving it state of its own would duplicate the C side. Every other class keeps the smell on. |

## Spinel widen warnings

None. `rake spinel_widen` fails on any warning.

## clang-tidy / cppcheck

| Check | Where | Why |
|---|---|---|
| `bugprone-easily-swappable-parameters` | `IgnoredParameterNames` adds `left` and `top` (`.clang-tidy`) | `ui_draw_text(slot, text, left, top, size, rgba)` keeps raylib's x-then-y order; structs cannot cross Spinel's FFI, so the two floats must be separate. The only caller is `Screen#draw_text`, which takes a Ruby `Point`, so a swap cannot happen at a call site that people write. The check stays on for every other parameter name. |

cppcheck: none.
