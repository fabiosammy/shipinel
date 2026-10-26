# Exceptions

Every place a check is relaxed, and why. CLAUDE.md requires each one to be
listed here. Thresholds (RuboCop Metrics, Flog, Flay, RubyCritic grades,
coverage) are never relaxed.

## RuboCop

| Cop | Where | Why |
|---|---|---|
| `Style/ComparableBetween` | disabled in `.rubocop.yml` | It asks for `x.between?(lo, hi)`. Under Spinel that pulls the Comparable builtins (`builtins/comparable.rb`) into the program, and they report six widen warnings, which this project treats as errors. `x >= lo && x <= hi` compiles cleanly and reads the same. |
| `Layout/LeadingCommentSpace` | `AllowRBSInlineAnnotation: true` | Not a relaxation of the rule's intent: `#: T` is the inline RBS syntax Spinel and rbs-inline read, and it has no space by definition. |

## Reek

None.

## Spinel widen warnings

None. `rake spinel_widen` fails on any warning.

## clang-tidy / cppcheck

None.
