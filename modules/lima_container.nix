{
  config,
  lib,
  ...
}: let
  cfg = config.lima;
  dockerSocketLocation = "sock/docker.sock";
in {
  imports = [./docker.nix ./podman.nix];
  options.lima.hostDockerSocketLocation = lib.mkOption {
    type = lib.types.str;
    default = "${cfg.vmConfigDir}/${dockerSocketLocation}";
    description = "location of the host exposed docker/podman socket";
  };
  config.lima.settings.message = ''
    #############################################
    ### NOTE: Container Support Configuration ###
    For setting up container support, you have to add the following code snippet
    to you shell profile, e.g. $HOME/.zprofile or $HOME/.bash_profile. This
    will configure DOCKER_HOST, CONTAINER_HOST and add docker to PATH

      NIXOS_LIMA_SHRC=${cfg.vmConfigDir}.shrc
      [ -r "$NIXOS_LIMA_SHRC" ] && . "$NIXOS_LIMA_SHRC"

    #############################################
  '';
}
