#!/usr/bin/env bash

NGINX_PORT=8888
NGINX_IMAGE=nginx

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


log "Starting nginx"
docker run -p $NGINX_PORT:80 $NGINX_IMAGE 2> /dev/null &

log "Nginx starting in background"
time (
  while ! curl --fail --silent localhost:$NGINX_PORT | grep 'Welcome to nginx'; do
    log "failed request to nginx"
    sleep 0.1
  done
  log "successfull request to nginx"
)
RESPONSIVITY=$(elapsed)

log "Nginx request successful. Shutting down"
kill %1
wait
log "DONE"
echo "$RESPONSIVITY"
