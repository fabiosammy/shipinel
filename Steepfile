# frozen_string_literal: true

require_relative "rakelib/support/paths"

# Steep type-checks lib/ under CRuby against the inline RBS (extracted by
# rbs-inline into tmp/, and removed after the check; see Paths) and the
# hand-written sig/.
target :lib do
  check "lib"
  # ui.rb is FFI declarations for Spinel; its types live in sig/ui.rbs.
  ignore "lib/shipinel/ui.rb"
  signature "sig", Paths::RBS_INLINE_DIR
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
