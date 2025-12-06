{
  description = "Documentation generator for Nix projects";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    imp-fmt.url = "github:imp-nix/imp.fmt";
    imp-fmt.inputs.nixpkgs.follows = "nixpkgs";
    imp-fmt.inputs.treefmt-nix.follows = "treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-unit,
      treefmt-nix,
      imp-fmt,
    }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f system);

      # Core Nix library
      coreLib = import ./nix/lib.nix { inherit lib; };

      # Schema types
      schema = import ./nix/schema.nix { inherit lib; };

      # Rust CLI (crate is named nixdoc internally, package exposed as docgen)
      mkDocgenCli =
        { rustPlatform, ... }:
        let
          cargo = lib.importTOML ./rs/Cargo.toml;
        in
        rustPlatform.buildRustPackage {
          pname = "docgen";
          version = cargo.package.version;
          src = ./rs;
          cargoLock.lockFile = ./rs/Cargo.lock;
          postInstall = ''
            mv $out/bin/nixdoc $out/bin/docgen
          '';
        };
    in
    {
      inherit schema;

      lib = coreLib;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.callPackage mkDocgenCli { };
          mdbook = pkgs.mdbook;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          formatterEval = imp-fmt.lib.makeEval {
            inherit pkgs treefmt-nix;
            rust.enable = true;
          };
        in
        {
          formatting = formatterEval.config.build.check self;

          docgen = self.packages.${system}.default.overrideAttrs (prev: {
            doCheck = true;
            postCheck = prev.postCheck or "" + ''
              ${pkgs.clippy}/bin/cargo-clippy --no-deps -- -D warnings
            '';
          });

          nix-unit =
            pkgs.runCommand "nix-unit-tests"
              {
                nativeBuildInputs = [ nix-unit.packages.${system}.default ];
              }
              ''
                export HOME=$TMPDIR
                nix-unit --expr 'import ${self}/nix/tests { lib = import ${nixpkgs}/lib; }'
                touch $out
              '';
        }
      );

      formatter = forAllSystems (
        system:
        imp-fmt.lib.make {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit treefmt-nix;
          rust.enable = true;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              cargo
              cargo-insta
              clippy
              rustfmt
              rustc
            ];
          };
        }
      );

      mkDocgen =
        {
          pkgs,
          lib ? pkgs.lib,
          manifest,
          srcDir,
          siteDir ? null,
          extraFiles ? { },
          docgenPkg ? self.packages.${pkgs.system}.default,
          mdbookPkg ? self.packages.${pkgs.system}.mdbook,
          optionsJson ? null,
          anchorPrefix ? "",
          name ? "docs",
          referenceDir ? "reference",
          localPaths ? {
            site = "./docs";
            src = "./src";
          },
          outputFiles ? {
            files = "files.md";
            methods = "methods.md";
            options = "options.md";
          },
        }:
        import ./nix/mkDocgen.nix {
          inherit
            lib
            pkgs
            manifest
            srcDir
            siteDir
            extraFiles
            mdbookPkg
            optionsJson
            anchorPrefix
            name
            referenceDir
            localPaths
            outputFiles
            ;
          nixdocPkg = docgenPkg;
          docgenLib = coreLib;
        };
    };
}
