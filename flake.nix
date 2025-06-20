{
  inputs = {
    nixpkgs.url = "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz";
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
    }:
    let
      # [ String ] -> String -> Any -> AttrSet
      # We pass in the flakeExposed systems, as that is a safe subset.
      #
      # Then this returns a function that has a string parameter. That string
      # is the attribute key.
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # Generate a set of common values for each system.
      # The key is common.${system}.{ packages, pkgs, craneLib }
      common = eachSystem (system: rec {
        packages = self.packages.${system};

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import self)
          ];
        };

        craneLib = crane.mkLib pkgs;
      });

      # Return a function with the common set of values at the parameter.
      forAllSystems = f: eachSystem (system: f common.${system});
    in
    {
      packages = forAllSystems (
        common:
        let
          inherit (common) pkgs;
        in
        {
          default = pkgs.wild;
        }
      );

      overlays.default = import self;

      formatter = forAllSystems (common: common.pkgs.nixfmt-tree);

      checks = forAllSystems (
        common:
        let
          inherit (common) pkgs;
        in
        {
          wild = pkgs.wild.overrideAttrs {
            doCheck = true;
            doInstallCheck = false;
            # Skip the build phase and don't install anything
            # because it ends up building libwild twice. Once for the buildPhase,
            # once for the checkPhase.
            dontBuild = true;
            installPhase = "touch $out";
          };
        }
        // (pkgs.wild.tests)
      );

      devShells = forAllSystems (common: {
        default = common.pkgs.callPackage ./nix/shell.nix {
          inherit (common) craneLib;
        };
      });
    };
}
