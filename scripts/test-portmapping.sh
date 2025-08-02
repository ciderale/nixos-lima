#!/usr/bin/env bash

PORT=${1:-8888}
RUNS=${2:-1}
IMAGE=alpine/socat
MESSAGE="SUCCESSFUL RESPONSE"
PROTOCOL=${3:-TCP}

#SOCAT_FLAGS=(-d -d -lu) for debugging
SOCAT_FLAGS=()

if [ "$RUNS" -gt 1 ]; then
  RESULTS=$(
    (for ((p=PORT; p<PORT+RUNS; p++)); do
      sleep 0.3; # minor delay to get a uniform load over time
      "$0" "$p" 1 "$PROTOCOL" &
      done
    ) | sort -n
  )
  echo "########################"
  echo "Excution durations [ms]:"
  echo "$RESULTS"
  exit
fi

function now() {
  echo $(($(date +%s%N)/1000000))
}

START=$(now)

function elapsed() {
  T=$(now)
  echo $((T - START))
}

function log() {
  printf "Elapsed: %6d ms: $1\n" "$(elapsed)" >&2
}


date -Ins >&2
log "Starting socat http server $PORT"
DOCKER_ID=$(docker run --rm -d -p "$PORT:$PORT/$PROTOCOL" "$IMAGE" \
  "${SOCAT_FLAGS[@]}" \
  "$PROTOCOL-LISTEN:$PORT,reuseaddr,fork" \
  EXEC:cat,nofork)
trap 'docker kill $DOCKER_ID > /dev/null' EXIT

log "Server start in background. Start Requests.."
date -Ins >&2
START=$(now)

# the backgrounded sleep is to avoid closing stdin to early
# this ensures that the response from socat is received
while ! (sleep 0.02 & echo "$MESSAGE") | socat "${SOCAT_FLAGS[@]}" - "$PROTOCOL:localhost:$PORT" | grep -- "$MESSAGE" >&2; do
  log "failed request"
done

RESPONSIVITY=$(elapsed)
log "### SUCCESSFULL REQUEST ###"
date -Ins >&2

if [ -n "${SOCAT_FLAGS[*]}" ]; then
  log "### show docker logs"
  docker logs "$DOCKER_ID"
fi

log "DONE"
echo "$RESPONSIVITY"

