# frozen_string_literal: true

# The C shim in ext/: strict compile, clang-tidy, cppcheck and clang-format.

require "shellwords"
require_relative "sources"

C_STRICT_FLAGS = %w[-std=c11 -Wall -Wextra -Wpedantic -Wconversion -Werror].freeze

# raylib and raygui headers come from pkg-config, as system headers, so that
# warnings inside raygui's implementation do not fail -Werror (docs/raylib-notes.md).
def raylib_include_flags
  Shellwords.split(`pkg-config --cflags-only-I raylib`).map { |flag| flag.sub(/\A-I/, "-isystem") }
end

desc "Run every native code gate on ext/"
task native_checks: %i[c_compile clang_tidy cppcheck clang_format]

desc "Compile ext/*.c with #{C_STRICT_FLAGS.join(' ')}"
task :c_compile do
  mkdir_p "build/ext"
  Sources::C_SOURCES.each do |source|
    sh "cc", *C_STRICT_FLAGS, *raylib_include_flags, "-c", source, "-o", "build/ext/#{File.basename(source, '.c')}.o"
  end
end

desc "clang-tidy with the checks in .clang-tidy"
task :clang_tidy do
  next puts("clang-tidy: no C sources yet") if Sources::C_SOURCES.empty?

  sh "clang-tidy", "--quiet", "--warnings-as-errors=*", *Sources::C_SOURCES,
     "--", *C_STRICT_FLAGS, *raylib_include_flags
end

desc "cppcheck with every finding as an error"
task :cppcheck do
  next puts("cppcheck: no C sources yet") if Sources::C_SOURCES.empty?

  sh "cppcheck", "--error-exitcode=1", "--enable=warning,style,performance,portability",
     "--inline-suppr", "--quiet", "--std=c11", *Sources::C_SOURCES
end

desc "clang-format: ext/ must already be formatted"
task :clang_format do
  next puts("clang-format: no C sources yet") if Sources::C_FILES.empty?

  sh "clang-format", "--dry-run", "--Werror", *Sources::C_FILES
end
