{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.lima;

  options.lima = {
    vsockPort = mkOption {
      type = types.ints.between 2222 2222;
      description = ''
        The ssh port on the host system.
        (not sure if it is configurable)
      '';
      default = 2222;
    };
    tick = mkOption {
      type = types.str;
      default = "3s";
      example = "300ms";
      description = ''
        tick for polling events (lima default: 3s)

        note: smaller values yield higher load by lime-guestagent
      '';
    };
    sighupTrigger = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        command to trigger port mapping update.

        update of port mapping is triggered for every newline of output of
        this command. the actual information of the output line is ignored.
      '';
    };
  };
in {
  inherit options;
  config = {
    systemd.services.lima-guestagent = {
      enable = true;
      description = "lima-guestagent for port forwarding";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "simple";
        # this get everything into the VM -- even qemu, not just the guestagent
        # ExecStart = "${pkgs.lima-bin}/share/lima/lima-guestagent.Linux-aarch64 daemon";
        ExecStart = "${cfg.cidata}/lima-guestagent daemon --vsock-port ${toString cfg.vsockPort} --tick ${cfg.tick}";
        Restart = "on-failure";
      };
    };
    systemd.services.lima-guestagent-push-events = lib.mkIf (cfg.sighupTrigger != null) {
      enable = true;
      description = "trigger portmapping updates";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "docker-events-push-lima-guestagent.sh" ''
          set -euo pipefail

          (${cfg.sighupTrigger}) | while read -r ; do
              AGENT_PID=$(systemctl show --property MainPID --value lima-guestagent)
              kill -HUP  "$AGENT_PID";
            done
        ''}";

        Restart = "on-failure";
      };
    };
  };
}
