{
  config,
  lib,
  ...
}: let
  cfg = config.lima;

  options.lima = {
    vmName = lib.mkOption {
      type = lib.types.str;
      default = "mynixos";
      description = "name of the lima VM";
    };
    vmConfigDir = lib.mkOption {
      type = lib.types.str;
      default = "/Users/${cfg.user.name}/.lima/${cfg.vmName}";
      description = "location of the lima configuration folder";
    };
  };
in {
  inherit options;
  imports = [
    ./base.nix
    ./lima_configuration.nix
    ./lima_configfile.nix
    ./lima_bootstrap.nix
    ./lima_mounts.nix
    ./lima_rosetta.nix
    ./lima_guestagent.nix
    ./shadow_lima_home_config.nix
  ];
}
