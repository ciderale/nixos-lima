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
docker run -p "$PORT:$PORT" "$IMAGE" \
  "TCP-LISTEN:$PORT,crlf,reuseaddr,fork" \
  SYSTEM:"echo HTTP/1.0 200; echo; echo '$MESSAGE'" &

log "Server start in background. Start Requests.."

while ! curl --fail --silent "localhost:$PORT" | grep -- "$MESSAGE" >&2; do
  log "failed request"
  sleep 0.02
done

RESPONSIVITY=$(elapsed)
log "### SUCCESSFULL REQUEST ###"

kill %1
wait
log "DONE"
echo "$RESPONSIVITY"

