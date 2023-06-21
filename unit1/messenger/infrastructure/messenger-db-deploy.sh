#!/bin/bash
set -e

PORT=5432
POSTGRES_USER=postgres
# NOTE: Never do this in a real-world deployment. Store passwords
# only in an encrypted secrets store.
# Because we’re focusing on other concepts in this tutorial, we
# set the password this way here for convenience.
POSTGRES_PASSWORD=postgres

# Migration user
POSTGRES_MIGRATOR_USER=messenger_migrator
# NOTE: As above, never do this in a real deployment.
POSTGRES_MIGRATOR_PASSWORD=migrator_password

docker run \
  --rm \
  --name messenger-db-primary \
  -d \
  -v db-data:/var/lib/postgresql/data/pgdata \
  -e POSTGRES_USER="${POSTGRES_USER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  -e PGPORT="${PORT}" \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  --network mm_2023 \
  postgres:15.1

echo "Register key messenger-db-port\n"
curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-port \
  -H "Content-Type: application/json" \
  -d "${PORT}"

echo "Register key messenger-db-host\n"
curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-host \
  -H "Content-Type: application/json" \
  -d 'messenger-db-primary' # This matches the "--name" flag above
                            # which for our setup means the hostname

echo "Register key messenger-db-application-user\n"
curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-application-user \
  -H "Content-Type: application/json" \
  -d "${POSTGRES_USER}"

curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-password-never-do-this \
  -H "Content-Type: application/json" \
  -d "${POSTGRES_PASSWORD}"

echo "Register key messenger-db-application-user\n"
curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-migrator-user \
  -H "Content-Type: application/json" \
  -d "${POSTGRES_MIGRATOR_USER}"

curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-migrator-password-never-do-this \
  -H "Content-Type: application/json" \
  -d "${POSTGRES_MIGRATOR_PASSWORD}"

printf "\nDone registering postgres details with Consul\n"
