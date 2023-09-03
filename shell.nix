{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  name = "dynip";

  # buildInputs is used for building the package, not for dev
  buildInputs = with pkgs; [
    curl.dev
    glibc
    zig
  ];

  # nativeBuildInputs is usually what you want -- tools you need to run
  nativeBuildInputs = with pkgs; [
    # This needs to get fixed by fetching deps manually
    # (pkgs.callPackage ./nix/pkgs/zls.nix { zig = zig."0.11.0"; })
    zls
  ];
}
