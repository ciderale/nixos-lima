{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.lima;
in
  lib.mkIf config.virtualisation.docker.enable {
    # lima user must be in group docker
    users.users.${cfg.user.name}.extraGroups = ["docker"];
    lima.settings.portForwards = [
      {
        guestSocket = "/run/docker.sock";
        hostSocket = cfg.hostDockerSocketLocation;
      }
    ];
    # ensure that test container finds the docker socket where it is on host
    virtualisation.docker.listenOptions = [cfg.hostDockerSocketLocation];
  }
