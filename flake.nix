{
  description = "tlx utilities package";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication defaultPoetryOverrides;
      in
      {
        packages = {
          tlx = mkPoetryApplication {
            projectDir = self;
            overrides = defaultPoetryOverrides;
          };
          default = self.packages.${system}.tlx;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.poetry
            pkgs.python3
          ];
        };
      }
    );
}
