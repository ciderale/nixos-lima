#!/usr/bin/env bash
set -euo pipefail

VERBOSE=${VERBOSE:-1}
SSH_ARGS_WITH_TARGET=("$@")
# arguments like: -F ~/.lima/mynixos/ssh.config lima-mynixos

function debug() {
  LEVEL=$1; shift
  if [ "$LEVEL" -lt "$VERBOSE" ]; then
    echo "${@}"
  fi
}

function active_ports() {
  podman container ls --format '{{.Ports}}' \
    | tr ',' '\n' | tr -d ' ' \
    | sed -n -e 's/\(.*\):\(.*\)->.*/127.0.0.1:\2:\1:\2/p' \
    | sort | uniq
}

function ssh_port_mapping() {
  if [ -n "$MAPPING" ]; then
    ssh "${SSH_ARGS_WITH_TARGET[@]}" -O "$MODE" -L "$MAPPING" || echo "failed ssh $MODE $MAPPING"
  fi
}

function ssh_all_ports() {
  echo "$PORTS" | while read -r line; do
    MODE=$MODE MAPPING=$line ssh_port_mapping
  done
}


function watch_expose_ports() {
  debug 0 "Starting partmapperd"
  LAST=
  (echo; podman events) | while read -r line; do

    NEW=$(active_ports)
    if [ "$LAST" = "$NEW" ]; then
      debug 2 "skip"
      continue
    fi
    trap 'PORTS=$NEW MODE=cancel ssh_all_ports' EXIT

    ADD=$(comm -1 -3 <(echo "$LAST") <(echo "$NEW"))
    REMOVE=$(comm -2 -3 <(echo "$LAST") <(echo "$NEW"))
    debug 1 "adding '$ADD'  removing '$REMOVE'"
    PORTS=$ADD MODE=forward ssh_all_ports
    PORTS=$REMOVE MODE=cancel ssh_all_ports

    LAST="$NEW"
  done
}

watch_expose_ports
