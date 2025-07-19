#!/usr/bin/env bash

PORT=8888
IMAGE=alpine/socat
MESSAGE="SUCCESSFUL RESPONSE"

function now() {
  echo $(($(date +%s%N)/1000000))
}


START=$(now)

function elapsed() {
  T=$(now)
  echo $((T - START))
}

function log() {
  printf "Elapsed: %6d ms: $1\n" "$(elapsed)"
}


log "Starting socat http server"
docker run -p $PORT:$PORT $IMAGE \
  TCP-LISTEN:$PORT,crlf,reuseaddr,fork \
  SYSTEM:"echo HTTP/1.0 200; echo; echo '$MESSAGE'" &

log "Server start in background. Start Requests.."

while ! curl --fail --silent localhost:$PORT | grep -- "$MESSAGE"; do
  log "failed request"
  sleep 0.02
done

RESPONSIVITY=$(elapsed)
log "### SUCCESSFULL REQUEST ###"

kill %1
wait
log "DONE"
echo "$RESPONSIVITY"
