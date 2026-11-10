# frozen_string_literal: true

# The release version `shipinel --version` prints. The same number is in
# flake.nix and spin.toml; `rake check_version` fails when they differ.

module Shipinel
  VERSION = "0.4.0"
end
