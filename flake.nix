{
  description = "AWS utilities. Things that should be in boto and more intuitive aws cli
  commands.";

  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , utils
    , ...
    }:
    utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      pythonPkgs = pkgs.python312Packages;
      #pyproject = pkgs.lib.importTOML ./pyproject.toml;
    in
    {
      # Executed by `nix build .`
      packages.default = pythonPkgs.buildPythonPackage {
        #pname = pyproject.project.name;
        #inherit (pyproject.project) version;
        pname = "tlx";
        version = "0.1.1";
        #format = "pyproject";
        pyproject = true;

        src = ./.;

        #build-system = [ pythonPkgs.hatchling ];
        build-system = [ pythonPkgs.setuptools ];

        dependencies = with pythonPkgs; [
          # Python dependencies
          boto3
          click
        ];

        buidInputs = with pkgs; [
          # Non Python dependencies
          # Build and/or run-time dependencies that need to be compiled for the host machine
          awscli2 # Although this is written in python it isn't a library. Its from nixpkgs
        ];
      };

      # Used by `nix develop`
      devShells.default = pkgs.mkShell
        {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            awscli2
            pyright
            python312Packages.ipython
            python312Packages.mypy
            python312Packages.mypy-boto3-cloudformation
            python312Packages.mypy-boto3-cloudformation
            python312Packages.mypy-boto3-cloudformation
            python312Packages.mypy-boto3-cloudformation
            python312Packages.mypy-boto3-cloudformation
          ];
          shellHook = ''
            # Needed because urllib appears twice on the Python path and awscli needs an
            # old version
            # https://github.com/NixOS/nixpkgs/issues/267864#issuecomment-2289482964
            export PYTHONPATH=""
          '';
        };
    });
}
