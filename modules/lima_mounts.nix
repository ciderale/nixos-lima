{
  config,
  lib,
  ...
}: let
  cfg = config.lima;

  # compute mountTag hash as done in lima-vm
  # https://github.com/lima-vm/lima/pull/5081
  # https://github.com/lima-vm/lima/issues/3957
  # https://github.com/lima-vm/lima/blob/master/pkg/limayaml/defaults.go#L97
  mountTag = location: mountPoint: let
    fullhash = builtins.hashString "sha256" "${location}:${mountPoint}";
  in "lima-${builtins.substring 0 16 fullhash}";

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
      value.device = mountTag location name;
      value.fsType = "virtiofs";
      value.options = ["nofail"]; # nofail: don't hang when mount is removed
    })
    cfg.settings.mounts;
in {
  ## filesystem mounts provided by user
  fileSystems = lib.listToAttrs fsMounts;
}
