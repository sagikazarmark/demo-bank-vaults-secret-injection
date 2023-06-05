{
  description = "Demo: Bank-Vaults secret injection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];

      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devenv.shells.default = {
          packages = with pkgs; [
            kind
            kubectl
            kustomize
            kubernetes-helm

            vault
          ];

          scripts = {
            versions.exec = ''
              kind --version
              kubectl version --short --client
              echo helm $(helm version --short)
              vault --version
            '';
          };

          enterShell = ''
            versions
          '';

          # https://github.com/cachix/devenv/issues/528#issuecomment-1556108767
          containers = pkgs.lib.mkForce { };
        };
      };
    };
}
