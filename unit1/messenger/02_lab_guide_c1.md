
# 挑战1: 定义应用级别微服务配置

进入目录`messenger`，后进行以下操作。

## 示例1

1. 修改源码 `app/index.mjs`

修改

```
app.use(express.json());

```

为 

```
app.use(express.json({limit: "20b"}));

```

2. 直接用Node.js运行messenger服务

```
cd app
npm install
node index.mjs
messenger_service listening on port 4000
```

3. 使用curl命令访问messenger服务，发送简短消息

```
curl -d '{ "text": "hello" }' -H "Content-Type: application/json" -X POST http://localhost:4000/conversations
...
{ "error": "Conversation must have 2 unique users" }
```

3. 使用curl命令访问messenger服务，发送超长消息

```
curl -d '{ "text": "hello, world" }' -H "Content-Type: application/json" -X POST http://localhost:4000/conversations
...
\”PayloadTooLargeError: request entity too large"

```

## 示例2

1. 修改配置文件`app/config/config.mjs`，将消息长度限制改成配置参数

```
jsonBodyLimit: {
doc: `The max size (with unit included) that will be parsed by the JSON middleware. Unit parsing is done by the https://www.npmjs.com/package/bytes library. ex: "100kb"`,
format: String,
default: null,
env: "JSON_BODY_LIMIT",
},
```

2. 修改源码 `app/index.mjs` 引用配置参数

将代码：

```
app.use(express.json({ limit: "20b" }));
```

修改为：

```
app.use(express.json({ limit: config.get("jsonBodyLimit") }));
```

3. 重启messenger服务并通过环境变量方式传入参数值

```
^c
JSON_BODY_LIMIT=27b node index.mjs
```

4. 使用curl命令访问messenger服务，再次发送超长消息

```
curl -d '{ "text": "hello, world" }' -H "Content-Type: application/json" -X POST http://localhost:4000/conversations
...
{ "error": "Conversation must have 2 unique users" }
```

5. 停止messenger服务

```
^c
```

6. 停止messenger-database服务

```
docker compose down
...failed to remove network mm_2023....
```

查看messenger-db数据库是否已停止：

```
docker ps --format '{{.Names}}'

consul-client
consul-server
rabbitmq

```