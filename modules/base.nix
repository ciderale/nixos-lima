{modulesPath, ...}: {
  imports = [
    ./hardware-configuration.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # note: networking.useDHCP keeps 0.0.0.0:68 bound permanently, while systemd.network rebinds to IP:68 after lease
  # this avoid that :68 is bound by the lima/host-agent on the host, which cause problems
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    networks."10-enp0s1" = {
      matchConfig.Name = "enp0s1";
      networkConfig.DHCP = "ipv4";
    };
  };
}
