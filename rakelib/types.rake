# frozen_string_literal: true

# Types: every method carries inline RBS, and Steep checks it under CRuby.

require_relative "support/paths"

RBS_INLINE_DIR = Paths::RBS_INLINE_DIR
# A signature line rbs-inline had to fill in: an un-annotated method or ivar.
UNTYPED_SIGNATURE = /^\s*[^#\s].*\buntyped\b/

desc "Steep type check, with every method annotated"
task type_checks: :steep

desc "Extract inline RBS into #{RBS_INLINE_DIR}"
task :rbs_inline do
  rm_rf RBS_INLINE_DIR
  sh "rbs-inline", "--opt-out", "--output=#{RBS_INLINE_DIR}", "lib"
end

desc "Fail if any method or ivar has no inline RBS annotation"
task rbs_annotated: :rbs_inline do
  missing = FileList["#{RBS_INLINE_DIR}/**/*.rbs"].flat_map do |path|
    File.readlines(path).grep(UNTYPED_SIGNATURE).map { |line| "#{path}: #{line.strip}" }
  end
  abort "missing inline RBS:\n#{missing.join("\n")}" if missing.any?
end

desc "Steep type check of lib/; the extracted RBS is removed afterwards"
task steep: :rbs_annotated do
  sh "steep", "check"
ensure
  rm_rf RBS_INLINE_DIR
end
