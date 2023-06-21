#!/bin/bash
set -e

# This configuration requires a new commit to change
NODE_ENV=production
PORT=4000
JSON_BODY_LIMIT=100kb

# Postgres database configuration by pulling information from 
# the system
POSTGRES_USER=$(curl -X GET http://localhost:8500/v1/kv/messenger-db-application-user?raw=true)
PGPORT=$(curl -X GET http://localhost:8500/v1/kv/messenger-db-port?raw=true)
PGHOST=$(curl -X GET http://localhost:8500/v1/kv/messenger-db-host?raw=true)
# NOTE: Never do this in a real-world deployment. Store passwords
# only in an encrypted secrets store.
PGPASSWORD=$(curl -X GET http://localhost:8500/v1/kv/messenger-db-password-never-do-this?raw=true)

# RabbitMQ configuration by pulling from the system
AMQPHOST=$(curl -X GET http://localhost:8500/v1/kv/amqp-host?raw=true)
AMQPPORT=$(curl -X GET http://localhost:8500/v1/kv/amqp-port?raw=true)

docker run \
  -d \
  -e NODE_ENV="${NODE_ENV}" \
  -e PORT="${PORT}" \
  -e JSON_BODY_LIMIT="${JSON_BODY_LIMIT}" \
  -e PGUSER="${POSTGRES_USER}" \
  -e PGPORT="${PGPORT}" \
  -e PGHOST="${PGHOST}" \
  -e PGPASSWORD="${PGPASSWORD}" \
  -e AMQPPORT="${AMQPPORT}" \
  -e AMQPHOST="${AMQPHOST}" \
  --network mm_2023 \
  messenger
