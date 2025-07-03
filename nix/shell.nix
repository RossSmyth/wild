{
  pkgs ? import <nixpkgs> { },
  craneLib ?
    let
      node = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes.crane.locked;
      crane = pkgs.fetchFromGitHub {
        inherit (node) owner repo rev;
        hash = node.narHash;
      };
    in
    pkgs.callPackage crane { },
}:
pkgs.mkShell {
  packages = [
    pkgs.binutils-unwrapped-all-targets
    pkgs.cargo-chef
    pkgs.llvmPackages_20.clang
    pkgs.lld
    pkgs.glibc.out
    pkgs.glibc.static
    pkgs.rustup
  ] ++ (pkgs.callPackage ./. { inherit craneLib; }).gccWrappers;

  env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
}
