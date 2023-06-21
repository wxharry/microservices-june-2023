# 准备工作

* 准备Linux/Unix开发环境
* 安装Node.js 19.x或者更高版本
* 安装Docker及Docker Compose
* curl 命令行工具
* jq 命令行工具

# 设置部署环境

1. 拉取实验代码
   
   ```
   mkdir ~/mj-2023-unit1
   cd ~/mj-2023-unit1
   git clone https://jihulab.com/microservices-june-2023-unit1/platform.git --branch main
   git clone https://jihulab.com/microservices-june-2023-unit1/messenger.git --branch main
   
   ```

2. 使用Docke部署平台支撑服务
   
   ```
   cd platform
   docker compose up -d --build
   ```
   
3. 使用Docker部署微服务支撑服务
   
   ```
   cd ../messenger
   docker compose up -d --build
   ```

4. 确认执行成功

 ```
docker ps --format "{{.Names}}"
 ```

输出：

 ```
messenger-db
consul-server
consul-client
rabbitmq
 ```