{
  description = "Shipinel: an always-visible window for a Markdown week plan";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Spinel from its release tarball: the archive vendors prism and the RBS
      # grammar, so plain `make` builds it without network (no `make deps`).
      spinel = pkgs.stdenv.mkDerivation rec {
        pname = "spinel";
        version = "2026.10.25";
        src = pkgs.fetchurl {
          url = "https://github.com/matz/spinel/releases/download/${version}/spinel-${version}.tar.xz";
          hash = "sha256-4TxzYOT4RbSmufNKgPtrgn+VCkgNGqM55ssl5ctho7A=";
        };
        buildFlags = [ "all" "tools" ];
        installFlags = [ "PREFIX=$(out)" ];
        # `spinel diff` runs spinel-diff from beside the compiler binary, but
        # `make install` only puts it in bin/ (docs/spinel-notes.md).
        postInstall = ''
          install -m 755 bin/spinel-diff $out/lib/spinel/spinel-diff
        '';
      };

      # Development gems (RuboCop, Steep, Reek, ...), locked by Gemfile.lock.
      # gemset.nix is generated from the lock with `bundix`.
      tools = pkgs.bundlerEnv {
        name = "shipinel-tools";
        ruby = pkgs.ruby_3_4;
        gemdir = ./.;
      };

      # raylib (built against GLFW with Wayland and X11) and the header-only
      # raygui. The cc wrapper adds their include and library paths.
      nativeLibs = [ pkgs.raylib pkgs.raygui ];

      devTools = [
        tools
        tools.wrappedRuby
        spinel
        pkgs.gcc
        pkgs.clang-tools
        pkgs.cppcheck
        pkgs.pkg-config
        pkgs.fontconfig
        pkgs.bundix
      ];
    in
    {
      packages.${system} = {
        inherit spinel;
        default = pkgs.stdenv.mkDerivation {
          pname = "shipinel";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [ spinel pkgs.pkg-config pkgs.makeWrapper ];
          buildInputs = nativeLibs;
          buildPhase = ''
            export HOME=$TMPDIR
            spin build
          '';
          # The app asks `fc-match` for its default fonts at run time.
          installPhase = ''
            install -D -m 755 build/bin/shipinel $out/bin/shipinel
            wrapProgram $out/bin/shipinel --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.fontconfig ]}
          '';
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = devTools ++ nativeLibs;
      };

      # `nix flake check` runs the same gate as `rake check`. Needs
      # gemset.nix (generate it with `bundix` after changing Gemfile.lock).
      checks.${system}.default = pkgs.stdenv.mkDerivation {
        name = "shipinel-rake-check";
        src = self;
        nativeBuildInputs = devTools;
        buildInputs = nativeLibs;
        buildPhase = ''
          export HOME=$TMPDIR
          rake check
        '';
        installPhase = "touch $out";
      };
    };
}
