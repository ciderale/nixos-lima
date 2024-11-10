{
  description = "NixOS on Lima Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable-small";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    guestSystem = "aarch64-linux";
    hostSystem = "aarch64-darwin";
    pkgs = nixpkgs.legacyPackages."${hostSystem}";
    packages = pkgs.callPackages ./nixos-lima.nix {};
  in {
    packages.aarch64-darwin = packages;

    nixosModules = {
      # the lima configuration module
      lima = import ./modules/lima.nix;
      # additional convenience modules
      disk-default = {
        imports = [inputs.disko.nixosModules.disko ./modules/disk-config.nix];
        disko.devices.disk.disk1.device = "/dev/vda";
      };
      docker = import ./modules/docker.nix;
    };

    templates.default = {
      path = ./example;
      description = "NixOS on MacOS via Lima-vm";
    };

    # an example for testing purposes (use template instead)
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = guestSystem;
      specialArgs = {inherit inputs;};
      modules = [
        self.nixosModules.lima
        self.nixosModules.disk-default
        self.nixosModules.docker
        ./example/lima-user.nix
        ./example/configuration.nix
      ];
    };

    devShells.${hostSystem}.default = pkgs.mkShellNoCC {
      buildInputs = builtins.attrValues packages;
    };
  };
}
