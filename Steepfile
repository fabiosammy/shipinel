# frozen_string_literal: true

# Steep type-checks lib/ under CRuby against the inline RBS (extracted by
# rbs-inline into build/rbs-inline) and the hand-written files in sig/.
target :lib do
  check "lib"
  # ui.rb is FFI declarations for Spinel; its types live in sig/ui.rbs.
  ignore "lib/shipinel/ui.rb"
  signature "sig", "build/rbs-inline"
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
