{
  description = "NixOS on Lima";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nixos-lima.url = "github:ciderale/nixos-lima";
    nixos-lima.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixos-lima,
    nixpkgs,
    ...
  }: let
  in {
    # an example for testing purposes
    nixosConfigurations.mynixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        nixos-lima.nixosModules.lima
        nixos-lima.nixosModules.disk-default
        nixos-lima.nixosModules.impure-config
        nixos-lima.nixosModules.lima-container
        ./lima-settings.nix
        ./configuration.nix
      ];
    };

    devShells = nixos-lima.devShells;
    packages = nixos-lima.packages;
  };
}
