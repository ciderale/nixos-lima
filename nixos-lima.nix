{
  writeShellApplication,
  nixos-rebuild,
  lima,
  nixos-anywhere,
  diffutils,
  openssh,
  jq,
  nix,
  gnused,
  docker-client,
  coreutils,
  fetchurl,
  socat,
}: rec {
  inherit docker-client socat lima;
  nixos-anywhere-mod = nixos-anywhere.overrideAttrs (old: {
    installPhase = ''
      # patch-in support for 'nix --impure'
      sed -i -e 's/case "$1" in/case "$1" in\n    --impure)\n      nixOptions+=(--impure)\n      ;;\n/' src/nixos-anywhere.sh
      ${old.installPhase}
    '';
  });
  test-portmapping = writeShellApplication {
    name = "test-portmapping";
    runtimeInputs = [docker-client socat coreutils];
    text = builtins.readFile ./scripts/test-portmapping.sh;
  };
  test-call-to-host = writeShellApplication {
    name = "test-call-to-host";
    runtimeInputs = [docker-client socat coreutils];
    text = builtins.readFile ./scripts/test-call-to-host.sh;
  };
  nixos-lima = writeShellApplication {
    name = "nixos-lima";
    runtimeInputs = [lima nixos-anywhere-mod nixos-rebuild diffutils jq nix gnused];
    text = ''
      NIXOS_LIMA_CONFIG_ROOT=$HOME/.lima
      mkdir -p "$NIXOS_LIMA_CONFIG_ROOT" # in case lima has never been run
      NIXOS_LIMA_CONFIG="$NIXOS_LIMA_CONFIG_ROOT/_config"
      NIXOS_LIMA_SSH_KEY="$NIXOS_LIMA_CONFIG/user"
      NIXOS_LIMA_IDENTITY_OPTS=(-i "$NIXOS_LIMA_SSH_KEY")
      NIXOS_LIMA_SSH_PUB_KEY="$NIXOS_LIMA_CONFIG/user.pub"
      TARGET_HOST=127.0.0.1 # workaround for https://github.com/NixOS/nix/issues/14148

      FLAKE_NAME=''${1:-}
      CMD=''${2:-}
      shift 2 || (
        limactl --version
        sed -E -n -e 's/^[[:space:]]+([^[:space:]]+)\)/usage: nixos-lima <VM_NAME> \1/p' "$0"
        echo "   VM_NAME is a flake attribute for a nixosConfiguration.VM_NAME"
        echo "           defaults to flake in current working dir if no no flake path given"
        exit 1
      )

      # extract FLAKE and NAME (and default to flake in current folder)
      if [[ ! "$FLAKE_NAME" =~ "#" ]]; then FLAKE_NAME=".#$FLAKE_NAME"; fi
      NAME=''${FLAKE_NAME#*#}
      FLAKE=''${FLAKE_NAME%#*}
      NIXOS_LIMA_VM_DIR="$NIXOS_LIMA_CONFIG_ROOT/$NAME"
      NIXOS_LIMA_VM_CONFIG_YAML="$NIXOS_LIMA_VM_DIR/lima.yaml"
      FLAKE_CONFIG_PATH="$FLAKE#nixosConfigurations.$NAME.config"
      NIXOS_LIMA_CONFIG_JSON="$NIXOS_LIMA_VM_DIR.full_config.json"
      VM_IMPURE_CFG="$NIXOS_LIMA_VM_DIR.vm-impure-config.nix"
      [ ! -e "$VM_IMPURE_CFG" ] && echo "{}" > "$VM_IMPURE_CFG"

      # set nixos configuration via impure environment variables
      export NIXOS_LIMA_IMPURE_CONFIG="$VM_IMPURE_CFG,''${NIXOS_LIMA_IMPURE_CONFIG:-}"
      NIXOS_LIMA_IMPURE=--impure

      function fail() {
        echo "$@"; exit 1
      }
      function write_configuration() {
          nix eval --json "$FLAKE_CONFIG_PATH.lima" "$NIXOS_LIMA_IMPURE" > "$NIXOS_LIMA_CONFIG_JSON"
      }
      function load_configuration() {
          USER_NAME="$(jq -e -r .user.name < "$NIXOS_LIMA_CONFIG_JSON")" || fail "no lima.user.name"
          SSH_PORT="$(jq -e -r .settings.ssh.localPort < "$NIXOS_LIMA_CONFIG_JSON")" || fail "no lima.settings.ssh.localPort"
          THE_TARGET="$USER_NAME@$TARGET_HOST"
      }
      function write_lima_yaml() {
          jq '.settings | del(.. | nulls)' < "$NIXOS_LIMA_CONFIG_JSON"
      }

      case "$CMD" in
        reboot)
          limactl stop -f "$NAME" && limactl start "$NAME"
          ;;

        delete)
          limactl stop -f "$NAME"
          limactl remove "$NAME"
          ;;

        stop|shell|list|ls)
          limactl "$CMD" "$NAME" "''${@}"
          ;;

        ssh)
          load_configuration
          ${openssh}/bin/ssh -p "$SSH_PORT" "$THE_TARGET" "''${NIXOS_LIMA_IDENTITY_OPTS[@]}"
          ;;

        write-shrc)
          echo "# NIXOS-LIMA: extract configuration parameters from nix module"
          load_configuration
          NIXOS_LIMA_VM_SHRC="$NIXOS_LIMA_VM_DIR.shrc"
          DOCKER_SOCKET=$(jq .hostDockerSocketLocation < "$NIXOS_LIMA_CONFIG_JSON")
          (
            echo "export DOCKER_HOST=unix://$DOCKER_SOCKET"
            echo "export CONTAINER_HOST=unix://$DOCKER_SOCKET"
            echo "PATH=${docker-client}/bin:\$PATH"
          ) > "$NIXOS_LIMA_VM_SHRC"
          ;;

        write-impure-config)
          cat > "$VM_IMPURE_CFG" <<-EOF
          {
            lima = {
              vmName="$NAME";
              user.name = "$(id -nu)";
              user.sshPubKey = "$(cat "$NIXOS_LIMA_SSH_PUB_KEY")";
            };
          }
      EOF
          ;;


        start)
          echo ""
          echo "#####################################"
          echo "# Welcome to the nixos-lima utility #"
          echo "#####################################"

          echo "# NIXOS-LIMA: starting VM $NAME -- creating and updating if necessary"
          echo "# NIXOS-LIMA: extract configuration parameters from nix module"
          write_configuration
          load_configuration

          echo "# NIXOS-LIMA: ensure vm exists"
          if ! limactl list "$NAME" | grep "$NAME"; then
            echo "# NIXOS-LIMA: create vm with lima"
            limactl create --name="$NAME" <(write_lima_yaml)

            echo "# NIXOS-LIMA: generate actual configuration files"
            $0 "$FLAKE_NAME" write-impure-config # in case pub key was created
            write_configuration # regenerate configuration
            load_configuration
            $0 "$FLAKE_NAME" write-shrc

            echo "# NIXOS-LIMA: regenerate the final lima.yml"
            write_lima_yaml > "$NIXOS_LIMA_VM_CONFIG_YAML"
            ssh-keygen -R "[$TARGET_HOST]:$SSH_PORT"
            limactl start "$NAME"

            echo "# NIXOS-LIMA: install nixos with nixos-anywhere"
            nixos-anywhere \
              $NIXOS_LIMA_IMPURE \
              -i "$NIXOS_LIMA_SSH_KEY" \
              --build-on remote "$THE_TARGET" -p "$SSH_PORT" \
              --post-kexec-ssh-port "$SSH_PORT" \
              --flake "$FLAKE_NAME"

            echo "# NIXOS-LIMA: ssh-keyscan to check if vm is up-and-running"
            while ! ssh-keyscan -4 -p "$SSH_PORT" $TARGET_HOST; do sleep 2; done

            echo "# NIXOS-LIMA: stop vm to avoid initial startup issues (sockets, etc)"
            $0 "$FLAKE_NAME" stop
            SKIP_NIXOS_REBUILD=yes
          fi
          echo "# NIXOS-LIMA: vm configuration exists"

          echo "# NIXOS-LIMA: ensure vm configuration lima.yaml is up-to-date"
          if ! diff -C 5 "$NIXOS_LIMA_VM_CONFIG_YAML" <(write_lima_yaml); then
            limactl stop -f "$NAME"
            write_lima_yaml > "$NIXOS_LIMA_VM_CONFIG_YAML"
          fi
          echo "# NIXOS-LIMA: lima.yaml is up-to-date"

          echo "# NIXOS-LIMA: ensure vm is up-and-running"
          if ! limactl list "$NAME" | grep Running; then
            limactl start "$NAME"
          fi
          echo "# NIXOS-LIMA: vm is running"

          if [ "''${SKIP_NIXOS_REBUILD:-}" != "yes" ]; then
            echo "# NIXOS-LIMA: Deploying $FLAKE_NAME to $THE_TARGET"
            export NIX_SSHOPTS="-o ControlPath=/tmp/ssh-nixos-vm-%n -o Port=$SSH_PORT ''${NIXOS_LIMA_IDENTITY_OPTS[*]}"
            nixos-rebuild \
              $NIXOS_LIMA_IMPURE \
              --flake "$FLAKE_NAME" \
              --no-reexec --target-host "$THE_TARGET" --build-host "$THE_TARGET" \
              --sudo \
              switch "$@"
          fi
          echo "# NIXOS-LIMA: vm is up-to-date and running"
          ;;
        *)
          echo "# NIXOS-LIMA: unknown command $CMD"
          ;;
      esac
    '';
  };
}
