{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.lima;

  # compute mountTag hash as done in lima-vm
  # https://github.com/lima-vm/lima/issues/3957
  # https://github.com/lima-vm/lima/blob/master/pkg/limayaml/defaults.go#L97
  # IFD implementation because \0 not possible in nix string
  macPkgs = import pkgs.path {system = "aarch64-darwin";};
  fullhash = location: mountPoint:
    builtins.readFile (
      macPkgs.runCommand "lima-tag" {} ''
        printf '%s\0%s' '${location}' '${mountPoint}' \
          | ${macPkgs.coreutils}/bin/sha256sum \
          > $out
      ''
    );

  fsMounts =
    lib.lists.imap0 (i: {
      location,
      writable ? false,
      mountPoint,
    }: let
      name =
        if mountPoint == null
        then location
        else mountPoint;
    in {
      inherit name;
      value.device = "lima-${builtins.substring 0 16 (fullhash location name)}";
      value.fsType = "virtiofs";
      value.options = ["nofail"]; # nofail: don't hang when mount is removed
    })
    cfg.settings.mounts;
in {
  ## filesystem mounts provided by user
  fileSystems = lib.listToAttrs fsMounts;
}
