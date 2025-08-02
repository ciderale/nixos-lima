#!/usr/bin/env bash

PORT=${1:-8888}
RUNS=${2:-1}
IMAGE=alpine/socat
MESSAGE="SUCCESSFUL RESPONSE"

if [ "$RUNS" -gt 1 ]; then
  RESULTS=$(
    (for ((p=PORT; p<PORT+RUNS; p++)); do
      sleep 0.3;
      "$0" "$p" 1 &
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


log "Starting socat http server $PORT"
DOCKER_ID=$(docker run --rm -d -p "$PORT:$PORT" "$IMAGE" \
  "TCP-LISTEN:$PORT,reuseaddr,fork" \
  EXEC:cat,nofork)
trap 'docker kill $DOCKER_ID > /dev/null' EXIT

log "Server start in background. Start Requests.."

# sleep after the echo so that socat does not exit before reading the response
while ! (echo "$MESSAGE"; sleep 0.02) | socat - "TCP:localhost:$PORT" | grep -- "$MESSAGE" >&2; do
  log "failed request"
done

RESPONSIVITY=$(elapsed)
log "### SUCCESSFULL REQUEST ###"

log "DONE"
echo "$RESPONSIVITY"

