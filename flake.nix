{
  description = "NixOS on Lima Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05-small";
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
      lima-container = import ./modules/lima_container.nix;
      impure-config = import ./modules/impure-config.nix;
    };

    templates.default = {
      path = ./example;
      description = "NixOS on MacOS via Lima-vm";
    };

    # an example for testing purposes (use template instead)
    nixosConfigurations.mynixos = nixpkgs.lib.nixosSystem {
      system = guestSystem;
      specialArgs = {inherit inputs;};
      modules = [
        self.nixosModules.lima
        self.nixosModules.disk-default
        self.nixosModules.impure-config
        self.nixosModules.lima-container
        ./example/lima-settings.nix
        ./example/configuration.nix
      ];
    };

    # application for uninstalled execution of mynixos
    apps.${hostSystem}.default = {
      type = "app";
      program = let
        app = pkgs.writeShellApplication {
          name = "mynixos";
          runtimeInputs = [self.packages.${hostSystem}.nixos-lima];
          text = ''nixos-lima ${self}#mynixos "''${@}"'';
        };
      in "${app}/bin/mynixos";
    };

    devShells.${hostSystem}.default = pkgs.mkShellNoCC {
      buildInputs = builtins.attrValues packages;
    };
  };
}
