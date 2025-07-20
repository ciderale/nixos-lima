{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.lima;
in
  lib.mkIf config.virtualisation.podman.enable {
    users.users.${cfg.user.name}.extraGroups = ["podman"];
    lima.settings.portForwards = [
      {
        guestSocket = "/run/podman/podman.sock"; # user must be in group docker
        hostSocket = cfg.hostDockerSocketLocation;
      }
    ];
    virtualisation.podman.dockerCompat = true;
    virtualisation.podman.dockerSocket.enable = true;
    systemd.sockets.podman.socketConfig.Symlinks = [
      cfg.hostDockerSocketLocation
      "/var/run/docker.sock"
    ];
    # trigger portmapping update in lima-guestagent
    lima.sighupTrigger = ''
      ${pkgs.podman}/bin/podman events \
        --filter event=start --filter event=stop --filter event=kill --filter event=die
    '';
  }
