#!/bin/bash
set -e

# Consul host and port are included in each host since we
# cannot query Consul until we know them
CONSUL_HOST="${CONSUL_HOST}"
CONSUL_PORT="${CONSUL_PORT}"

docker run \
  --rm \
  -d \
  --name messenger-lb \
  -e CONSUL_URL="${CONSUL_HOST}:${CONSUL_PORT}"  \
  -p 8085:8085 \
  --network mm_2023 \
  messenger-lb
