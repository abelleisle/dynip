{
  description = "dynip - Dynamic IP Service";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          devShells.default = pkgs.mkShell {
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
          };
        }
      );
}
