# 挑战2: 为微服务创建部署脚本

进入目录`messenger`，后进行以下操作。

## 创建部署脚本

1. 创建目录与空脚本文件

```
mkdir infrastructure
cd infrastructure
touch messenger-deploy.sh
chmod +x messenger-deploy.sh
touch messenger-db-deploy.sh
chmod +x messenger-db-deploy.sh

```

2. 在配置中心Consul中增加RabbitMQ的访问配置信息

```
curl -X PUT --silent --output /dev/null --show-error --fail \
  -H "Content-Type: application/json" \
  -d "rabbitmq" \
  http://localhost:8500/v1/kv/amqp-host

curl -X PUT --silent --output /dev/null --show-error --fail \
  -H "Content-Type: application/json" \
  -d "5672" \
  http://localhost:8500/v1/kv/amqp-port

```

2. 修改messenger-deploy.sh脚本，支持从外部注册中心读取配置，并启动messenger服务容器

```
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
  --rm \
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

```

3. 修改messenger-db-deploy.sh脚本，支持部署数据库时将访问信息写入配置中心

```
#!/bin/bash
set -e

PORT=5432
POSTGRES_USER=postgres
# NOTE: Never do this in a real-world deployment. Store passwords
# only in an encrypted secrets store.
POSTGRES_PASSWORD=postgres

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

echo "Register key messenger-db-password-never-do-this\n"
curl -X PUT --silent --output /dev/null --show-error --fail http://localhost:8500/v1/kv/messenger-db-password-never-do-this \
  -H "Content-Type: application/json" \
  -d "${POSTGRES_PASSWORD}"

printf "\nDone registering postgres details with Consul\n"

```

## 运行部署脚本

1. 编译docker镜像

```
cd ../app
docker build -t messenger .
```

2. 验证platform相关支撑服务容器已正常启动

```
docker ps --format '{{.Names}}'
consul-server
consul-client
rabbitmq
```

3. 基于容器重新部署messenger服务与messenger依赖的数据库

```
cd ..
./infrastructure/messenger-db-deploy.sh
./infrastructure/messenger-deploy.sh
```

查看启动结果：

```
docker ps --format '{{.Image}}, {{.Names}}'

messenger, cranky_solomon
postgres:15.1, messenger-db-primary
hashicorp/consul:1.14.4, consul-client
hashicorp/consul:1.14.4, consul-server
rabbitmq:3.11.4-management-alpine, rabbitmq
```

4. 调用messenger服务的健康检查接口

```
curl localhost:4000/health
curl: (7) Failed to connect to localhost port 4000 after 11 ms: Connection refused
```

5. 关闭容器为下一次挑战做准备

```
docker rm $(docker stop $(docker ps -a -q --filter ancestor=messenger --format="{{.ID}}"))

```

确认messenger容器已关闭：

```
docker ps --format '{{.Names}}'
consul-server
consul-client
rabbitmq
```