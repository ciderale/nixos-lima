{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.lima;

  # rfc42 settings format (but serialize to json manually)
  settingsFormat = pkgs.formats.yaml {};

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
    settings = mkOption {
      default = {};
      description = ''
        Lima configuration settings.

        for details see https://github.com/lima-vm/lima/blob/master/examples/default.yaml
      '';
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          # disable the lima-builtin containerd
          containerd.user = mkEnableOption "User-Level Containerd";
          containerd.system = mkEnableOption "System-Level Containerd";
          message = mkOption {
            type = types.lines;
            description = ''
              Message. Information to be shown to the user, given as a Go template for the instance.
              The same template variables as for listing instances can be used, for example {{.Dir}}.
            '';
          };
          images = mkOption {
            type = types.listOf (types.submodule {
              options = {
                location = mkOption {type = types.str;};
                arch = mkOption {type = types.str;};
                digest = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
              };
            });
            description = "bootstrap images -- not important, will be replaced by nixos-anywhere anyway";
            default = [
              {
                location = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img";
                arch = "x86_64";
              }
              {
                location = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img";
                arch = "aarch64";
              }
            ];
          };

          # Selected options from lima.yaml. Additional options can be specified
          vmType = mkOption {
            type = types.enum ["vz"];
            description = "The Virtualization Framework";
            default = "vz";
          };
          ssh.localPort = mkOption {
            type = types.int;
            description = "The ssh port on the host system";
            default = 2222;
          };
          rosetta.enabled = mkOption {
            type = types.bool;
            description = "Enable Rosetta in hypervisor & nixos";
            default = cfg.settings.vmType == "vz";
          };
          video.display = mkOption {
            type = types.str;
            default = "none";
            description = ''
              QEMU display, e.g., "none", "cocoa", "sdl", "gtk", "vnc", "default".
              # Choosing "none" will hide the video output, and not show any window.
              # Choosing "vnc" will use a network server, and not show any window.
              # Choosing "default" will pick the first available of: gtk, sdl, cocoa.
              # 🟢 Builtin default: "none"
            '';
          };

          mounts = mkOption {
            type = types.listOf (types.submodule {
              options = {
                location = mkOption {
                  type = types.str;
                };
                mountPoint = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
                writable = mkOption {
                  type = types.bool;
                  default = false;
                };
              };
            });
          };

          portForwards = mkOption {
            type = types.listOf (types.submodule {
              options = {
                guestSocket = mkOption {
                  type = types.str;
                  description = ''
                    "guestSocket" can include these template variables: {{.Home}}, {{.UID}}, {{.User}}, and {{.Param.Key}}.

                    Forwarding requires the lima user to have rw access to the "guestsocket",
                  '';
                };
                hostSocket = mkOption {
                  type = types.str;
                  description = ''
                    "hostSocket" can include {{.Home}}, {{.Dir}}, {{.Name}}, {{.UID}}, {{.User}}, and {{.Param.Key}}.

                    Put sockets into "{{.Dir}}/sock" to avoid collision with Lima internal sockets!
                    Forwarding requires the local user to have rwx access to the directory of the "hostsocket".
                  '';
                };
              };
            });
          };
        };
      };
    };
  };
in {
  inherit options;
  imports = [
    ./lima_configfile.nix
    ./lima_bootstrap.nix
    ./lima_mounts.nix
    ./lima_rosetta.nix
    ./lima_guestagent.nix
    ./shadow_lima_home_config.nix
    ./base.nix
  ];
}
