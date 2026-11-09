# frozen_string_literal: true

require_relative "test_helper"
require_relative "../../rakelib/support/version_bump"

class VersionBumpTest < Minitest::Test
  FLAKE = <<~NIX
    spinel = pkgs.stdenv.mkDerivation rec {
      version = "2026.10.25";
    };
    default = pkgs.stdenv.mkDerivation {
      pname = "shipinel";
      version = "0.2.0";
    };
  NIX

  # Spinel's own pinned version stays.
  def test_flake_changes_only_the_shipinel_package
    bumped = VersionBump.flake(FLAKE, "0.3.0")

    assert_includes bumped, %(version = "2026.10.25";)
    assert_includes bumped, %(  version = "0.3.0";\n};\n)
  end

  def test_spin_and_ruby
    assert_equal [%([package]\nversion = "0.3.0"\n), %(  VERSION = "0.3.0"\n)],
                 [VersionBump.spin(%([package]\nversion = "0.2.0"\n), "0.3.0"),
                  VersionBump.ruby(%(  VERSION = "0.2.0"\n), "0.3.0")]
  end

  def test_only_plain_versions
    VersionBump.check("1.0.0")

    assert_raises(ArgumentError) { VersionBump.check("v1.0.0") }
  end
end
