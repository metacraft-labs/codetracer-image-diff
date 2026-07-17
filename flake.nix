{
  description = "codetracer-image-diff — perceptual image diff for CodeTracer visual-replay (NVIDIA FLIP CPU build)";

  inputs = {
    codetracer-toolchains.url = "github:metacraft-labs/nix-codetracer-toolchains";
    nixpkgs.follows = "codetracer-toolchains/nixpkgs";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem =
        {
          pkgs,
          system,
          lib,
          ...
        }:
        let
          toolchainsPkgs = inputs."codetracer-toolchains".packages.${system};
          isLinux = lib.hasInfix "linux" system;
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              # Nim toolchain
              toolchainsPkgs.nim-2_2
              toolchainsPkgs.nimble

              # Build tools — we need a C++ toolchain for the FLIP shim.
              pkgs.pkg-config
              pkgs.just
              pkgs.gcc

              # libpng kept in the shell for developers who want to
              # double-check our stb-emitted PNGs against a battle-tested
              # decoder. Not linked into the library itself.
              pkgs.libpng
            ];

            shellHook = ''
              ${lib.optionalString isLinux ''
                export LD_LIBRARY_PATH="${
                  lib.makeLibraryPath [
                    pkgs.libpng
                  ]
                }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              ''}
            '';
          };

          # `nix run` entrypoint runs the test suite. The dev shell is
          # the primary developer surface; this app is a convenience for
          # CI.
          apps.default = {
            type = "app";
            program = toString (pkgs.writeShellScript "image-diff-test" ''
              export PATH="${
                lib.makeBinPath [
                  toolchainsPkgs.nim-2_2
                  toolchainsPkgs.nimble
                  pkgs.pkg-config
                  pkgs.gcc
                ]
              }:$PATH"
              exec nimble test
            '');
          };
        };
    };
}
