# frozen_string_literal: true

# Paths shared by the Rakefile and the Steepfile.

# See the file comment.
module Paths
  # rbs-inline writes the signatures of lib/ here for Steep, and the type
  # check removes them again: spin passes `--rbs <project root>` and Spinel
  # reads every .rbs below it, so a generated (possibly stale) copy left in
  # the tree would be fed back to the compiler. `rake rbs_only_in_sig`
  # fails the Spinel gate if one is ever left behind.
  RBS_INLINE_DIR = "tmp/rbs-inline"
end
