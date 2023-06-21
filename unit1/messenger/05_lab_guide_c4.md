
# 挑战4: 使用定时任务服务迁移数据库

## 迁移messenger数据库

1. 创建一个PostgreSQL的超级用户，用于数据库迁移

```
echo "CREATE USER messenger_migrator WITH SUPERUSER PASSWORD 'migrator_password';" | docker exec -i messenger-db-primary psql -U postgres

```

2.  修改infrastructure/messenger-db-deploy.sh脚本，增加新的访问用户和密码写入配置中心逻辑


```
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

```

3. 创建数据库迁移服务部署脚本

```
touch infrastructure/messenger-db-migrator-deploy.sh
chmod +x infrastructure/messenger-db-migrator-deploy.sh

```

4. 编辑messenger-db-migrator-deploy.sh脚本，增加迁移逻辑


```

#!/bin/bash
set -e

# This configuration requires a new commit to change
NODE_ENV=production
PORT=4000
JSON_BODY_LIMIT=100kb

CONSUL_SERVICE_NAME="messenger-migrator"

# Consul host and port are included in each host since we
# cannot query Consul until we know them
CONSUL_HOST="${CONSUL_HOST}"
CONSUL_PORT="${CONSUL_PORT}"

# Get the migrator user name and password
POSTGRES_USER=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-migrator-user?raw=true")
PGPORT=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-port?raw=true")
PGHOST=$(curl -X GET http://localhost:8500/v1/kv/messenger-db-host?raw=true)
# NOTE: Never do this in a real-world deployment. Store passwords
# only in an encrypted secrets store.
PGPASSWORD=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-migrator-password-never-do-this?raw=true")

# RabbitMQ configuration by pulling from the system
AMQPHOST=$(curl -X GET "http://localhost:8500/v1/kv/amqp-host?raw=true")
AMQPPORT=$(curl -X GET "http://localhost:8500/v1/kv/amqp-port?raw=true")

docker run \--rm \
  -d \
  --name messenger-migrator \
  -e NODE_ENV="${NODE_ENV}" \
  -e PORT="${PORT}" \
  -e JSON_BODY_LIMIT="${JSON_BODY_LIMIT}" \
  -e PGUSER="${POSTGRES_USER}" \
  -e PGPORT="${PGPORT}" \
  -e PGHOST="${PGHOST}" \
  -e PGPASSWORD="${PGPASSWORD}" \
  -e AMQPPORT="${AMQPPORT}" \
  -e AMQPHOST="${AMQPHOST}" \
  -e CONSUL_HOST="${CONSUL_HOST}" \
  -e CONSUL_PORT="${CONSUL_PORT}" \
  -e CONSUL_SERVICE_NAME="${CONSUL_SERVICE_NAME}" \
  --network mm_2023 \
  messenger

```

5. 重新部署PostgreSQL数据库

```
docker stop messenger-db-primary
CONSUL_HOST=consul-client CONSUL_PORT=8500 ./infrastructure/messenger-db-deploy.sh

```

6. 部署PostgreSQL数据库迁移服务

```
CONSUL_HOST=consul-client CONSUL_PORT=8500 ./infrastructure/messenger-db-migrator-deploy.sh

```

7. 确认数据库迁移服务容器正常启动

```
docker ps --format "{{.Names}}"
...
messenger-migrator

```

8. 运行数据库迁移脚本

```
docker exec -i -e PGDATABASE=postgres -e CREATE_DB_NAME=messenger messenger-migrator node scripts/create-db.mjs
docker exec -i messenger-migrator node scripts/create-schema.mjs
docker exec -i messenger-migrator node scripts/create-seed-data.mjs
docker stop messenger-migrator

```

## 测试messenger服务

1. 创建一个对话

```
curl -d '{"participant_ids": [1, 2]}' -H "Content-Type: application/json" -X POST 'http://localhost:8085/conversations'
{
  "conversation": { "id": "1", "inserted_at": "YYYY-MM-DDT06:41:59.000Z" }
}

```

2. 在对话中，用户ID 1 发送一条消息

```
curl -d '{"content": "This is the first message"}' -H "User-Id: 1" -H "Content-Type: application/json" -X POST 'http://localhost:8085/conversations/1/messages' | jq
{
  "message": {
    "id": "1",
    "content": "This is the first message",
    "index": 1,
    "user_id": 1,
    "username": "James Blanderphone",
    "conversation_id": 1,
    "inserted_at": "YYYY-MM-DDT06:42:15.000Z"
  }
}

```

3. 在对话中，用户ID 2 回复一条消息

```
curl -d '{"content": "This is the second message"}' -H "User-Id: 2" -H "Content-Type: application/json" -X POST 'http://localhost:8085/conversations/1/messages' | jq
{
  "message": {
    "id": "2",
    "content": "This is the second message",
    "index": 2,
    "user_id": 2,
    "username": "Normalavian Ropetoter",
    "conversation_id": 1,
    "inserted_at": "YYYY-MM-DDT06:42:25.000Z"
  }
}

```

4. 查询消息记录

```
curl -X GET 'http://localhost:8085/conversations/1/messages' | jq
{
  "messages": [
    {
      "id": "1",
      "content": "This is the first message",
      "user_id": "1",
      "channel_id": "1",
      "index": "1",
      "inserted_at": "YYYY-MM-DDT06:42:15.000Z",
      "username": "James Blanderphone"
    },
    {
      "id": "2",
      "content": "This is the second message",
      "user_id": "2",
      "channel_id": "1",
      "index": "2",
      "inserted_at": "YYYY-MM-DDT06:42:25.000Z",
      "username": "Normalavian Ropetoter"
    }
  ]
}

```

