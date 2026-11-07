# Spinel notes for Shipinel

What Spinel allows and forbids, as it affects this app. Written from the
`matz/spinel` docs at release **2026.10.25** (`README.md`, `docs/limitations.md`,
`docs/FFI.md`, `docs/spin.md`, `docs/inline-rbs.md`, `docs/rbs-extract.md`) and
from its `test/` suite. Each point is marked **(docs)** or **(test: name)**.
The points that mattered most were then checked with the built compiler
(`spinel 2026.10.25 (2814693f6)`, gcc 12.2) against CRuby 3.4.10; see
[Verified with the compiler](#verified-with-the-compiler). Reproducers for
anything that fails are under [Reproducers](#reproducers).

## Toolchain facts

- Releases are dated tags. Pinned release: `2026.10.25`, archive
  `spinel-2026.10.25.tar.xz`, sha256
  `e13c7360e4f845b4a6b9f34a80fb6b827f950a480d1aa339e6cb25e5cb61a3b0`
  (SRI `sha256-4TxzYOT4RbSmufNKgPtrgn+VCkgNGqM55ssl5ctho7A=`). The archive
  vendors prism and the ruby/rbs grammar, so `make` builds it without network.
  `make install PREFIX=$out` installs `spinel` and `spin`. **(docs)**
- `spinel` is a single C binary: Ruby → C → `cc -O2`. The compiled binary needs
  only libc + libm, plus whatever `ffi_lib` adds (raylib here). **(docs)**
- `spinel --version` prints `2026.10.25 (rev) [cc]`. **(docs)**
- Flags we use: `--rbs DIR` (seed types from `.rbs` files), `--warn-widen`
  (warn when a parameter or return widens to untyped, the boxed slow path),
  `-c` (emit C only), `--debug` (backtraces with lines). **(docs)**
- `spinel diff FILE -- args` runs a program under CRuby and Spinel and prints
  one label: `same`, `output-diff`, `exception-diff`, `compile-error`,
  `link-error`, `crash`, `timeout` or `nondeterministic`. Exit 0 means `same`.
  **(docs)**
- Integers are int64; overflow raises by default. Fine for line indexes and
  pixels. **(docs)**

## `spin` (project tool)

- `spin.toml` is the manifest. Each `bin/*.rb` is an executable;
  `spin build` writes `build/bin/<name>`. **(docs)**
- `require "shipinel/x"` resolves to `<package root>/shipinel/x.rb`. Our
  library lives in `lib/shipinel/`, so we either point `-I` at `lib/` or use
  `require_relative` everywhere. **Plan:** `require_relative` in every file;
  Spinel resolves it at parse time by inlining, and CRuby and Steep handle it
  the same way. **(docs)**
- `spin build` always compiles with the **require gate** on: stdlib needs its
  `require` exactly as in CRuby, and a bundled library loads only what it uses.
  **(docs)**
- **Carried C:** a package compiles only the `.c` files its manifest lists:

  ```toml
  [package]
  name = "shipinel"
  sources = ["ext/ui_shim.c"]
  ```

  A `.c` in the tree that is not listed is reported and skipped. Headers next
  to it stay on the include path. Objects are cached per
  (package, version, toolchain); `SPIN_NO_NATIVE_CACHE=1` disables the cache
  for debugging. `CC` picks the compiler. **(docs)**
- **`ffi_source` vs carried `.c`:** `ffi_source` pastes C into the generated
  translation unit, so it has to be a compile-time string. CLAUDE.md asks for a
  carried `.c`, and the docs recommend the same, so we use a carried `.c`.
  **(docs)**
- `spin test` treats each `test/*.rb` as a program. With no
  `test/<name>.rb.expected`, it runs the same file under CRuby and compares
  stdout. `--regen` freezes the snapshot. A non-zero exit or a diff fails.
  Snapshot tests use plain `puts` / `raise`, not Minitest. **(docs)**
- `spin` writes `build/` (we gitignore it) and `spin.lock` (commit it; we
  have no deps anyway). **(docs)**
- `spin flags` prints the `spinel` flags a build would use, for driving
  `spinel` directly (e.g. `--warn-widen --rbs sig`) from `rake`.
  **Open question:** whether `spin build` forwards extra `spinel` flags. If it
  does not, `rake check` runs `spinel $(spin flags) --rbs sig --warn-widen
  bin/shipinel.rb` for the warn-widen gate, and `spin build` produces the
  artifact. **(docs)**

## Ruby subset: what this app must avoid

Fundamental (never supported) **(docs)**:

- `eval`, string `instance_eval` / `class_eval`, `method_missing` (defining it
  only warns, it is never dispatched), `define_method` / `send` /
  `public_send` with a computed name, `ObjectSpace`, `TracePoint`, `binding`,
  refinements, `callcc`.
- Runtime structural mutation through an explicit receiver
  (`Klass.include(M)` from a method, etc.).
- `remove_method` / `undef_method`: refused.
- `IO.popen`: refused. Use backticks or `Open3.capture2` (bundled `open3`).
- `File.read` with `mode:` / `open_args:` options: refused. Use `File.read(path)`
  / `File.binread(path)`. **But do not use `binread`/`binwrite`:** under CRuby
  they return BINARY strings, which then raise `Encoding::CompatibilityError`
  against UTF-8 literals, while Spinel is UTF-8 only. On Linux `File.read` /
  `File.write` keep CRLF bytes as they are, so they are the right pair.
  **(compiled: probes/io.rb)**
- `Array#hash` and user-defined `hash` / `eql?` for Hash keys: not dispatched.
  We key hashes only by Integer / String / Symbol, if at all.
- User-object `==` in `include?` / `index` compares identity unless the class
  defines `==`. Struct defines `==`, so Struct value objects are fine.

`rubocop_spinel` 0.2.0 (May 2026; it predates this release, so it is stricter
than the compiler) flags these. The cop also bans `extend`, `const_get`,
`define_singleton_method`, `singleton_method`, `class << self`, `prepend`, and
`Thread` / `Mutex`, so we write module functions as `def self.x` and never
use `extend self`. **(rubocop_spinel source)**

## Types and inference

- Whole-program inference. Each slot (param, return, ivar, local) gets one C
  type. Two callers passing different types widen the slot to `poly` (a tagged
  union, dispatched at run time). `--warn-widen` reports each widening; CLAUDE.md
  makes those errors, so **every slot must stay monomorphic**. **(docs)**
- Things that widen, and the rules we follow to avoid them:
  - `nil` meeting Integer / Float / bool widens to untyped, **except** ivars
    written nil, `Integer?` seeds and container reads, which use the
    `sp_oint` (value + nil flag) form. `nil` meeting a String or an object is
    a nullable pointer and does **not** widen. **Rule:** no `Integer | nil`
    returns from methods; use a sentinel (`-1`) or a separate predicate, or
    annotate `Integer?` explicitly. **(docs)**
  - Mixed element kinds in one Array give a `poly_array`; an empty `[]` has no
    element kind until something is pushed. **Rule:** arrays hold one class;
    seed empty arrays with an RBS type (`# @rbs @blocks: Array[Block]`).
    **(docs)**
  - A typed Array (`Array[Integer]`, `Array[String]`) refuses a store of another
    kind at run time (`TypeError`). **(docs)**
- **Value objects:** `Struct.new(..., keyword_init: true)` is supported (60
  tests); `Data.define` too (181 tests). Small classes (≤ 8 scalar fields, no
  inheritance, never mutated through parameters) become stack value types with
  no GC. **(docs, tests)**
- **Block kinds as subclasses (decided, compiled).** An Array of objects has
  no typed form: a local or a return value holding objects is always
  `Array[untyped]` and `--warn-widen` reports it, whether it holds one class
  or a hierarchy, Struct or class. Only an **ivar** narrows to the unboxed
  pointer array (`sp_PtrArray`), and only while every use of it is one of
  `[]`, `[]=`, `<<`/`push`, `pop`, `shift`, `size`/`length`, `empty?`,
  `first`/`last`, `clear`, `delete_at` from the owning class's own methods (no
  `each`/`map`/`select`). Such an array accepts subclasses. **Rule:** a list of
  objects lives in an ivar of a small owner class (`Document` owns its blocks,
  `DrawList` its draw commands), which exposes `add`, `size` and `at(index)`;
  callers loop with `while index < list.size`. With that, `Block` base class
  + `Heading`, `Task`, `Bullet`, `Paragraph`, `Rule`, `CodeLine` subclasses
  compile with zero widen warnings. **(compiled: probes/doc.rb)**
- **No annotated method overrides.** When a subclass overrides a method, all
  overrides share one return representation and Spinel ignores each
  annotation's return type with a warning ("the method is overridden in a
  related class"). **Rule:** subclasses add data and readers, never override
  a base method other than `initialize`; type dispatch is `is_a?` checks (or
  the base class's `kind` Symbol). `is_a?` narrows the static type, so
  `b.checked? if b.is_a?(Task)` compiles. **(compiled: probes/blocks.rb)**
- Comparable works on any class with `<=>`. **(docs)**

### RBS

- Inline RBS is on by default. Forms we use: `#: (Integer) -> String` directly
  above a `def` (no blank line in between), `attr_reader :x #: String`,
  `# @rbs @ivar: T` as a standalone block in the class body (blank line after
  it). **(docs)**
- Supported types: `Integer`, `Float`, `String`, `Symbol`, `bool`, `nil`,
  program classes, `Array[T]`, `Hash[String|Symbol, V]`, `T?`. Not supported,
  so the whole annotation is dropped with a warning: tuples, records-as-types
  are boxed, literal types, interfaces, generics, procs, **optional positional
  parameters** (the whole signature is ignored), overloads. **Rule:** no
  optional positional params in annotated methods; use keywords.
  **(docs)**
- A seed is an **assertion**: a wrong one is reinterpreted, not converted
  (closer to `reinterpret_cast`). A provable contradiction is a compile error.
  Build tests with `-DSP_RBS_CHECK` to turn silent misreads into aborts.
  **(docs)**
- Inline annotations don't attach to methods inside `Struct.new` blocks,
  `class << self`, or top-level `def`s (confirmed: "this comment block has no
  supported declaration on the following line"). A `#:` on a **local**
  assignment (`blocks = [] #: Array[Block]`) is not applied either; seed ivars
  with `# @rbs @name: T` instead. **Rule:** Struct value objects are
  `Name = Struct.new(...)` followed by `class Name` (reopen) for methods, so
  the methods are in a static class body and take pins. **(docs)**
- External `sig/*.rbs` and inline annotations must agree exactly
  (`Integer` ≠ `Integer?`). We keep inline RBS as the source of truth and use
  `sig/` only for what inline cannot say (the FFI module, the Struct members).
  **(docs)**

## Strings, regexps, encoding

- **String literals are always frozen**, with no opt-out
  (`# frozen_string_literal: false` is ignored with a warning). Mutable strings
  come from `+"lit"`, `String.new`, `dup` or interpolation. This matches the
  `# frozen_string_literal: true` we put in every file anyway. **(docs)**
- UTF-8 only. The engine has no transcoding. `length` counts characters.
  Portuguese text is plain UTF-8, so this is fine. **(docs)**
- Built-in NFA regexp engine: `=~`, `match`, `match?`, `sub`/`gsub`, `scan`,
  `split`, named captures (51 tests use `(?<name>`). `\d \w \s` are ASCII;
  POSIX brackets are Unicode. Equal regexp literals share one object.
  **(docs, tests)** **Rule:** use `MatchData` with named captures
  (`m[:mark]`), never `$1`.
- Embedded NUL bytes are preserved by the core methods. Irrelevant for
  Markdown. **(docs)**
- `split`, `lines`, `each_line`, `chomp` are supported (`lines`: 202 tests).
  Line-ending handling for CRLF files is ours: split on `"\n"`, strip a
  trailing `"\r"` for parsing, and keep the raw line for writing back.

## File and process APIs

Spinel implements these (test counts are files in `test/` using them):

| API | Evidence | Use in Shipinel |
|---|---|---|
| `File.read` | 174 tests, compiled | read the document (CRLF kept; not `binread`, see above) |
| `File.write` | 174 tests, compiled | write the temp file |
| `File.rename` | `test/file_unlink_rename.rb` | atomic replace (rename(2)) |
| `File.exist?` | 42 tests | missing-file state |
| `File.dirname`, `File.basename`, `File.join` | 8 / 20 / 133 tests | temp file next to the target |
| `File.unlink` | `test/file_unlink_rename.rb` | clean up a failed temp write |
| `File.mtime` | 3 tests | not needed: we compare content |
| `Process.clock_gettime` | 21 tests | 500 ms poll timer |
| `Errno::ENOENT`, `SystemCallError` | 26 / 42 tests | rescue at the IO boundary |
| backtick `` `cmd` `` | (docs) | `fc-match -f '%{file}' sans` |
| `ARGV`, `exit`, `warn`, `abort` | (docs, tests) | CLI |

**`File.rename` vs libc `rename(2)` through FFI (decided 2026-11-07: `File.rename`).** CLAUDE.md says "call libc
`rename(2)` through FFI". Spinel's `File.rename` **is** `rename(2)`, and it
works under CRuby, where the unit tests run. An FFI declaration cannot be
loaded under CRuby (`ffi_func` is not a CRuby method), so `DocumentFile` would
need an injected renamer just for the tests. **Proposal:** use `File.rename`.
If you want the FFI route anyway, it is `ffi_func :rename, [:str, :str], :int`
in a `LibC` module (libc is always linked) behind a `Renamer` seam.

## FFI

Declarations live in a `module` body; the module name is the namespace
(`UI.draw_text(...)`). **(docs)**

| spec | C type | Ruby type |
|---|---|---|
| `:int`, `:int32`, `:uint32`, `:long`, `:size_t`, ... | that C int type | Integer (int64 inside, cast at the call) |
| `:float` / `:double` | `float` / `double` | Float |
| `:bool` | `int` | true / false |
| `:str` | `const char *` (NUL-terminated) | String (nil passes NULL) |
| `:ptr` | `void *` | opaque pointer |
| `:int_array` / `:float_array` | `const int64_t *` / `const double *` | typed Array (call-duration only) |
| `:void` | `void` | return only |

- `ffi_lib "raylib"` adds `-lraylib`; `ffi_cflags "..."` adds include or link
  paths. libc and libm are always linked. **(docs)**
- `ffi_const :NAME, 4` declares an integer constant, `Module::NAME`. **(docs)**
- Each `extern` is declared under a private name with an asm label, so it never
  clashes with a real header prototype. **(docs)**
- **Not supported: structs by value.** raylib passes `Color`, `Vector2`,
  `Rectangle` and `Font` by value, so the C shim takes scalars (x, y, w, h,
  `uint32` RGBA) and builds the structs itself. No variadic functions.
  **(docs)**
- **`:ptr` rules:** not GC-tracked and never freed for us. A `:ptr` must
  **not** go into a polymorphic array or a generic Hash. Keep it in a local or
  in a class ivar typed `ptr`. NULL compares `== nil`. **We avoid `:ptr`
  altogether:** the shim keeps the loaded fonts as static C state, and Ruby
  refers to them by small integer ids (0 = body, 1 = mono). **(docs)**
- A `:str` argument is valid only for the call; C must copy it if it keeps it.
  The shim never keeps one. **(docs)**
- `ffi_buffer` / `ffi_read_*` / `ffi_struct` / `ffi_callback` exist but we
  don't need them. **(docs)**
- **CRuby side:** `ffi_func` is not a CRuby method, so `lib/shipinel/ui.rb`
  cannot be loaded by CRuby, Minitest or Steep. It is required only from
  `bin/shipinel.rb`. Everything else receives the UI as an injected object
  (`Screen`), and the tests pass a recording fake. Steep sees `sig/ui.rbs`
  and ignores `ui.rb`. RuboCop and Reek still lint it as text.
  (`RUBY_ENGINE == "spinel"` branches are dropped before analysis, which is
  another option, but injection keeps it simpler.) **(docs)**

## Exceptions

- `begin` / `rescue` / `ensure` / `retry`, custom exception classes and
  `rescue Errno::ENOENT => e` work. `e.message` and `e.class` work.
  **(docs, tests)**
- `backtrace` is `[]` in a release build; use `--debug` for lines. **(docs)**
- A call that cannot exist on a known receiver type is a **compile error**,
  not a runtime `NoMethodError`, so "rescue NoMethodError" code does not
  build. **(docs)**
- An ivar used before its assigning method ran segfaults in a release build
  (`NoMethodError` only with `--debug`). **Rule:** assign every ivar in
  `initialize`. **(docs)**

## Verified with the compiler

Probes live in the session scratchpad (`probes/*.rb`), compiled with
`spinel --warn-widen` and diffed against `ruby`. Results:

1. **`spin build` has no `--warn-widen` / `--rbs` switch** and no manifest key
   for compiler flags. `spin flags` prints exactly what `spin build` compiles
   with (minus entry and `-o`), so the checked build is
   `spinel $(spin flags) --rbs sig --warn-widen bin/shipinel.rb -o build/bin/shipinel`,
   and `spin build` is run separately to prove the plain build is clean.
2. **Struct vs classes:** classes chosen (see "Block kinds as subclasses").
   No Struct is needed for blocks, so the reopened-Struct question is moot.
3. **Named captures with Symbol keys** (`m[:text]`) work and match CRuby.
4. **CRLF round-trip** through `File.write` → `File.rename` → `File.read` keeps
   `\r\n` and a missing trailing newline; `String#size` counts characters
   (25) and `bytesize` bytes (28) for `"- [ ] Reunião\r\n- [x] ação"`, as CRuby.
5. **Backticks** return `fc-match` output (`/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`
   here, no trailing newline with `-f '%{file}'`). We test for an empty result
   rather than `$?`.
6. **`Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)`** returns
   an Integer. `rescue Errno::ENOENT` around `File.read` works.
7. **More rules found while probing:**
   - `each_with_index` (and other Enumerator-backed helpers) pulls Spinel's
     own `builtins/enumerator.rb` into the program, which reports ~35 widen
     warnings inside the compiler's builtins. **Rule:** plain `each` / `while`
     with a counter.
   - A method whose last expression is a `while` loop, or a `case`/`if` whose
     branches yield different types, gets an untyped return ("born here: no
     untyped input"), even when annotated `-> void`. **Rule:** end such a
     method with an explicit `nil`.
   - `String#index` (with or without an offset) pulls the same Enumerator
     builtins in. **Rule:** scan with `text[position, marker.size] == marker`
     in a loop and return `-1` for "not found" (which also avoids an
     `Integer?` return).
   - **Any identifier named `index`, `find`, `count` or `detect`** (method,
     parameter or local variable) does the same, even in code unrelated to
     Enumerable; `select`, `map`, `first`, `size`, `position` and the like do
     not. Found with `spinel-reduce --oracle-cmd`. Reproducer:
     `i = 0` works, `index = 0; while index < 2; index += 1; end` → 35 widen
     warnings, all inside `builtins/`. **Rule:** never use those four names;
     say `position` (in a list) or `line_index` (in the file).
   - An `# @rbs @ivar: T` line directly above a method's `#:` comment is
     read as part of that method's comment and ignored ("belongs to the
     method's leading comment block"). **Rule:** a blank line after the ivar
     declarations.
   - `is_a?` narrows a variable for the calls inside the branch, but not a
     value **returned** from there: `return block if block.is_a?(Task)` in a
     method annotated `-> Task?` is refused ("annotation contradicted ... this
     returns Block"). **Rule:** return the base type (`Block?`) and let the
     caller check `is_a?` again.
   - `Comparable#between?` (and `clamp`) pulls `builtins/comparable.rb` in,
     which reports six widen warnings. **Rule:** `x >= lo && x <= hi`
     (`Style/ComparableBetween` is off for this reason, docs/exceptions.md).
8. **Install layout bug in 2026.10.25:** `spinel diff` execs
   `<dir of the real spinel binary>/spinel-diff`, i.e. `$PREFIX/lib/spinel/`,
   but `make install` puts the tool only in `$PREFIX/bin/`. Fix after install:
   `install -m 755 bin/spinel-diff $PREFIX/lib/spinel/` (flake.nix does this
   in `postInstall`).
9. **`spin` reads every `.rbs` in the package tree** (`spin flags` passes
   `--rbs <package root>`). Gems installed under `vendor/bundle` brought their
   own `.rbs` files and broke the build ("declares BigDecimal#% twice"), so the
   bundle lives outside the repo (`bundle config set --local path
   ~/.cache/shipinel-bundle`). `build/` is skipped.

## Found while building the C shim (phase 4)

- **Include flags for carried C:** `spin` compiles a carried `.c` with only
  `-O2 -I <package root>`. External headers come from a `[native]` table in
  `spin.toml`: `pkg_config = ["raylib"]` adds `pkg-config --cflags raylib`
  (read from `tools/spin.rb`, `native_objs_for`). Linking comes from
  `ffi_lib "raylib"` in `ui.rb`, which the generated C carries as
  `/* SPINEL_LINK: -lraylib */`.
- **`:bool` is a C `int`.** A shim function declared `bool` but bound as
  `:bool` would only set the low byte of the return register. Every shim
  function that answers yes/no returns `int` (1/0) and is bound as `:int`;
  `Screen` compares with `== 1`.
- **`spin test` runs each program with `test/` as its working directory**,
  while `spinel diff` runs from the project root. A snapshot that writes
  `build/...` therefore writes `test/build/...` under `spin test`
  (gitignored).
- **`spinel -c` still runs the full analysis**, so `spinel --rbs sig
  --warn-widen bin/shipinel.rb -c -o x.c` checks the app for widening even
  where raylib cannot be linked.
- `bin/shipinel.rb` now requires `ui.rb`, so `spinel diff` (which also runs
  CRuby) only covers the `test/*.rb` programs.

## Reproducers

Nothing has been refused so far. The constructs above that compile but widen
are reproduced by these minimal programs (`spinel --warn-widen x.rb`):

```ruby
# 35 widen warnings, all inside builtins/enumerator.rb and enumerable.rb
"a\nb\n".lines.each_with_index { |l, i| puts "#{i} #{l}" }
```

```ruby
# "the return of `f` widened to untyped": the while loop is the last expression
class C
  #: (String s) -> void
  def f(s)
    i = 0
    while i < s.size
      i += 1
    end
  end
end
C.new.f("ab")
```

```ruby
# six widen warnings inside builtins/comparable.rb
class D
  #: (Integer n) -> bool
  def ok?(n) = n.between?(1, 9)
end
puts D.new.ok?(3)
```
