#!/usr/bin/env bash

PORT=${1:-8888}
HOST=${2:-host.docker.internal}
PROTOCOL=${3:-TCP}
IMAGE=alpine/socat
MESSAGE="SUCCESSFUL RESPONSE"

#SOCAT_FLAGS=(-d -d -lu) for debugging
SOCAT_FLAGS=()

socat "${SOCAT_FLAGS[@]}" \
  "$PROTOCOL-LISTEN:$PORT,reuseaddr,fork" \
  EXEC:cat,nofork &
SOCAT_PID=$!
echo $SOCAT_PID
trap 'kill $SOCAT_PID > /dev/null' EXIT

if (echo "$MESSAGE"; sleep 0.1) | \
   docker run --rm --entrypoint sh "$IMAGE" \
    -c "(echo $MESSAGE; sleep 0.1) | socat ${SOCAT_FLAGS[*]} - '$PROTOCOL:$HOST:$PORT'" \
  | grep -- "$MESSAGE" >&2;
then
  echo "Call successful"
  exit 0
else
  echo "Call FAILED"
  exit 1
fi
