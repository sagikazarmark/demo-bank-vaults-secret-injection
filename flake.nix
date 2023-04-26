{
  description = "Demo: Bank-Vaults secret injection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        versions = pkgs.writeScriptBin "versions" ''
          kind --version
          kubectl version --short --client
          echo helm $(helm version --short)
          vault --version
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [ versions ] ++ (with pkgs; [
            versions

            kind
            kubectl
            kustomize
            kubernetes-helm

            vault
          ]);

          shellHook = ''
            versions
          '';
        };
      }
    );
}
