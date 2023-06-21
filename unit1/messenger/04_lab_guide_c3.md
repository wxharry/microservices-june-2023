# 挑战3: 对外发布服务

## 修改程序支持把服务实例注册到Consul注册中心

1. 修改app/index.mjs引入Consul访问库，并修改程序，支持启动后立即注册到Consul

引入Consul访问库：

```
import { register as registerConsul } from "./consul/index.mjs";

```

支持启动后注册：

```
/* =================
  SERVER START
================== */
app.listen(port, async () => {
  console.log(`messenger_service listening on port ${port}`);
  registerConsul();
});

export default app;

```

2. 修改app/config/config.mjs，增加Consul相关的配置参数

```
consulServiceName: {
    doc: "The name by which the service is registered in Consul. If not specified, the service is not registered",
    format: "*",
    default: null,
    env: "CONSUL_SERVICE_NAME",
  },
  consulHost: {
    doc: "The host where the Consul client runs",
    format: String,
    default: "consul-client",
    env: "CONSUL_HOST",
  },
  consulPort: {
    doc: "The port for the Consul client",
    format: "port",
    default: 8500,
    env: "CONSUL_PORT",
  },

```

3. 再次修改infrastructure/messenger-deploy.sh脚本，增加messenger服务的Consul注册配置信息

```

#!/bin/bash
set -e

# This configuration requires a new commit to change
NODE_ENV=production
PORT=4000
JSON_BODY_LIMIT=100kb

CONSUL_SERVICE_NAME="messenger"

# Consul host and port are included in each host since we
# cannot query Consul until we know them
CONSUL_HOST="${CONSUL_HOST}"
CONSUL_PORT="${CONSUL_PORT}"

# Postgres database configuration by pulling information from 
# the system
POSTGRES_USER=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-application-user?raw=true")
PGPORT=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-port?raw=true")
PGHOST=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-host?raw=true")
# NOTE: Never do this in a real-world deployment. Store passwords
# only in an encrypted secrets store.
PGPASSWORD=$(curl -X GET "http://localhost:8500/v1/kv/messenger-db-password-never-do-this?raw=true")

# RabbitMQ configuration by pulling from the system
AMQPHOST=$(curl -X GET "http://localhost:8500/v1/kv/amqp-host?raw=true")
AMQPPORT=$(curl -X GET "http://localhost:8500/v1/kv/amqp-port?raw=true")

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
  -e CONSUL_HOST="${CONSUL_HOST}" \
  -e CONSUL_PORT="${CONSUL_PORT}" \
  -e CONSUL_SERVICE_NAME="${CONSUL_SERVICE_NAME}" \
  --network mm_2023 \
  messenger

```

4. 重新编译messenger的容器镜像，在编译前先停止已启动容器

```
cd app
docker rm $(docker stop $(docker ps -a -q --filter ancestor=messenger --format="{{.ID}}"))
docker build -t messenger .

```

5. 在浏览器中访问Consul的管理界面

```
http://localhost:8500

```

6. 在messenger的根目录下，执行脚本重新部署messenger服务

```
CONSUL_HOST=consul-client CONSUL_PORT=8500 ./infrastructure/messenger-deploy.sh

```

7. 在Consul管理界面中查看注册成功的messenger服务实例

```
http://localhost:8500

```

8. 再部署3个messenger实例，确认所有实例都成功启动并注册到Consul

```
CONSUL_HOST=consul-client CONSUL_PORT=8500 ./infrastructure/messenger-deploy.sh

```

## 设置NGINX

1. 创建load-balancer目录，并创建空脚本文件

```
mkdir load-balancer
cd load-balancer
touch nginx.ctmpl
touch consul-template-config.hcl
touch Dockerfile

```

2. 修改nginx.ctmpl模板文件，用于动态配置messenger服务实例到NGINX上游实例列表中

```
upstream messenger_service {
    {{- range service "messenger" }}
    server {{ .Address }}:{{ .Port }};
    {{- end }}
}

server {
    listen 8085;
    server_name localhost;

    location / {
        proxy_pass http://messenger_service;
        add_header Upstream-Host $upstream_addr;
    }
}

```

3. 修改consul-template-config.hcl支持监听Consul获取配置变更信息，并重新生成配置文件

```
consul {
  address = "consul-client:8500"

  retry {
    enabled  = true
    attempts = 12
    backoff  = "250ms"
  }
}
template {
  source      = "/usr/templates/nginx.ctmpl"
  destination = "/etc/nginx/conf.d/default.conf"
  perms       = 0600
  command     = "if [ -e /var/run/nginx.pid ]; then nginx -s reload; else nginx; fi"
}

```

3. 修改Dockerfile支持编译NGINX的docker容器镜像

```
FROM nginx:1.23.1

ARG CONSUL_TEMPLATE_VERSION=0.30.0

# Set an environment variable for the location of the Consul
# cluster. By default, it tries to resolve to consul-client:8500
# which is the behavior if Consul is running as a container in the 
# same host and linked to this NGINX container (with the alias 
# consul, of course). But this environment variable can also be
# overridden as the container starts if we want to resolve to
# another address.

ENV CONSUL_URL consul-client:8500

# Download the specified version of Consul template
ADD https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip /tmp

RUN apt-get update \
  && apt-get install -y --no-install-recommends dumb-init unzip \
  && unzip /tmp/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip -d /usr/local/bin \
  && rm -rf /tmp/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip

COPY consul-template-config.hcl ./consul-template-config.hcl
COPY nginx.ctmpl /usr/templates/nginx.ctmpl

EXPOSE 8085

STOPSIGNAL SIGQUIT

CMD ["dumb-init", "consul-template", "-config=consul-template-config.hcl"]


```

5. 编译Docker容器镜像

```
docker build -t messenger-lb .

```

6. 创建messenger-load-balancer-deploy.sh脚本，用于部署NGINX实例

```
cd ..
touch infrastructure/messenger-load-balancer-deploy.sh
chmod +x infrastructure/messenger-load-balancer-deploy.sh

```

7. 修改infrastructure/messenger-load-balancer-deploy.sh脚本，增加部署逻辑

```
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

```

8. 部署NGINX实例

```
CONSUL_HOST=consul-client CONSUL_PORT=8500 ./infrastructure/messenger-load-balancer-deploy.sh

```

验证部署成功：

```
docker ps --format '{{.Image}}, {{.Names}}'

```
结果：

```
messenger-lb, messenger-lb
messenger, charming_shockley
messenger, practical_booth
messenger, frosty_wu
messenger, naughty_bartik
hashicorp/consul:1.14.4, consul-server
hashicorp/consul:1.14.4, consul-client
rabbitmq:3.11.4-management-alpine, rabbitmq

```
9. 通过NGINX代理访问messenger服务

```
curl -X GET http://localhost:8085/health
OK

```
