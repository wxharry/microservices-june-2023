
# 清理测试环境

1. 删除Docker容器

```
docker rm $(docker stop $(docker ps -a -q --filter ancestor=messenger --format="{{.ID}}"))
docker rm $(docker stop messenger-db-primary)
docker rm $(docker stop messenger-lb)

```

2. 删除platform服务

```
cd ../platform

# From the platform repository
docker compose down

```

3. 删除容器镜像

```
docker rmi messenger
docker rmi messenger-lb
docker rmi postgres:15.1
docker rmi hashicorp/consul:1.14.4
docker rmi rabbitmq:3.11.4-management-alpine

```
