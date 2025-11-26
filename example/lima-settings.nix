{
  config,
  lib,
  ...
}: {
  documentation.enable = false; # saves about 0.1GB

  #lima.settings.plain = true; #disables mounts,ports,ga,etc
  lima.settings.ssh.localPort = 2222;
  lima.settings.mounts = [
    {
      location = "/Users/${config.lima.user.name}";
      writable = true;
    }
  ];
  #lima.settings.video.display = "vz"; add gui
  lima.settings.memory = lib.mkDefault "8GB";
  lima.settings.cpus = lib.mkDefault 8;
  lima.settings.disk = lib.mkDefault "60GB";
  virtualisation.containers.registries.search = [
    "docker.io"
    "quay.io"
  ];
  networking.firewall.enable = false; # firwall may interfere with kind (kubernetes in docker)
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    # --add-host host.docker.internal=host-gateway yields ip of host not vm
    host-gateway-ips = [config.lima.hostLimaInternal];
  };
  lima.settings.hostResolver = {
    enabled = true;
    hosts."host.docker.internal" = "host.lima.internal";
  };
  # virtualisation.podman.enable = true;
  #nix.settings.trusted-users = ["ale"];
}
