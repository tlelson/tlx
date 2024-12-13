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
      pkgs = import nixpkgs {
        inherit system;
      };
      pythonPkgs = pkgs.python312Packages;
      #pyproject = pkgs.lib.importTOML ./pyproject.toml;
    in
    {
      # Executed by `nix build .`
      packages.default = pythonPkgs.buildPythonPackage
        {
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

          nativeBuidInputs = with pkgs; [
            makeWrapper # provides wrapProgram
          ];

          buidInputs = with pkgs; [
            # Non Python dependencies
            # Build and/or run-time dependencies that need to be compiled for the host machine
            awscli2 # Although this is written in python it isn't a library. Its from nixpkgs
            gnused
            unixtools.column
            jq
          ];

          # TODO: make a function to itterate over all shell files
          postInstall = ''
            wrapProgram $out/bin/checkhealth \
                --set PATH ${pkgs.python312Packages.python.interpreter}/bin:$PATH \
                --set SHELL ${pkgs.bash}/bin/bash
          '';
        };

      # Used by `nix develop`
      devShells.default = pkgs.mkShell
        {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            python312
            awscli2
            pyright
          ] ++ (with pkgs.python312Packages; [
            setuptools
            ipython
            mypy
            mypy-boto3-cloudformation
            mypy-boto3-codepipeline
            mypy-boto3-iam
            mypy-boto3-logs
            mypy-boto3-organizations
            mypy-boto3-s3
            mypy-boto3-secretsmanager
          ]);
          #shellHook = ''
          ## NOTE: Breaks import of above modules
          ## Needed because urllib appears twice on the Python path and awscli needs an
          ## old version
          ## https://github.com/NixOS/nixpkgs/issues/267864#issuecomment-2289482964
          #export PYTHONPATH=""
          #'';
        };
    });
}
