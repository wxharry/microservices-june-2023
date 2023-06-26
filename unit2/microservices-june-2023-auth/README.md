# Unit 2实验教程：如何安全地管理容器中的Secrets

## 教程概述

在本教程中，我们将展示当客户端容器访问服务时如何安全地分发和使用JSON Web Token（JWT）。在本教程的四个挑战中，您将尝试使用四种不同的Secrets管理方法，以学习如何在容器中正确地管理Secrets，并了解几种不完善的Secrets管理方法：在本教程中，我们将展示当客户端容器访问服务时如何安全地分发和使用JSON Web Token（JWT）如何安全地分发和使用客户端容器用于访问服务的 JSON Web 令牌 (JWT)。在本教程的四个挑战中，您将尝试使用四种不同的Secrets密钥管理方法，以学习如何在容器中正确地管理Secrets密钥，并了解几种不完善的Secrets密钥管理方法：

- 将Secrets硬编码至应用
- 将Secrets作为环境变量传递
- 使用本地Secrets
- 使用Secrets Manager

虽然本教程使用 JWT 作为Secrets示例，但这些技巧适用于任何您需要用来保存Secrets的载体，例如数据库凭证、SSL 私钥及其他 API 密钥。

本教程用到了两个主要的软件组件：

- API 服务器——一个运行 NGINX 开源版和一些基本 NGINX JavaScript 代码的容器，它可从 JWT 中提取声明，并从其中一个声明中返回一个值，如果没有声明，则返回一条错误消息
- API 客户端——一个运行简单 Python 代码的容器，只向 API 服务器发起 GET 请求

## 准备工作和设置

### 准备工作

要想在自己的环境中完成本教程的实验，您需要：

- 一个兼容 Linux/Unix 的环境
- 基本了解 Linux 命令行
- nano 或 vim 等文本编辑器
- Docker（包括 Docker Compose 和 Docker Engine Swarm）。
- curl（已安装在大多数系统上）
- git（已安装在大多数系统上）

**注：**

- 本教程使用了一个侦听 80端口 的测试服务器。如果 80 端口已被占用，则可在使用 docker run 命令启动测试服务器时，使用 ‑p 标记为该服务器设置其他值。然后，使用 curl 命令时在 localhost 上添加 :<port_number> 后缀。
- 本教程中省略了 Linux 命令行提示符，以便您将命令复制和粘贴到终端。

### 设置

在本节中，您需要复制教程代码库并生成JWT，启动身份验证服务器，并在有无令牌两种情况下发送测试请求。

**复制教程代码库仓库**

1.在家目录下，创建 microservices-june 目录，并将 Jihulab 代码库复制到其中。（您也可以使用其他目录名称，相应修改指令即可）。该代码库包含配置文件以及使用不同方法来获取Secrets的 API 客户端应用的多个版本。

```bash
mkdir ~/microservices-june
cd ~/microservices-june
git clone https://jihulab.com/f5will/microservices-june-2023-auth.git
```

2.签发一个测试的JWT，可以使用以下网站来生成JWT：
[https://tooltt.com/jwt-encode/](https://tooltt.com/jwt-encode/)

![生成JWT](https://jihulab.com/f5will/microservices-june-2023-auth/-/raw/main/pic/jwt.png?inline=false)

请注意其中的Subject字段，**必须**使用自己的名字，这会作为我们验证实验完成情况的依据！

将生成的Token保存至以下目录并命名为*token1.jwt*

```bash
cat ~/microservices-june/microservices-june-2023-auth/apiclient/token1.jwt
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjpbeyJ0b29sdHQiOiJodHRwczovL3Rvb2x0dC5jb20ifV0sImlhdCI6MTY4MzAyMTAxOSwiZXhwIjoxNzE0NTc5MTk5LCJhdWQiOiIiLCJpc3MiOiJOR0lOWCIsInN1YiI6Ind0YW5nIn0.3v0plqdGVcppD6WCEOFV2o_IOygzbOR-soqKbK07l3A
```

虽然可通过多种方法使用该令牌进行身份验证，但在本教程中，API 客户端应用使用OAuth 2.0 Bearer令牌授权框架将其传递给身份验证服务器。这需要您在 JWT 前面加上 *Authorization: Bearer* 前缀，如本例所示：

```http
"Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNpZ24ifQ.eyJpYXQiOjE2NzUyMDA4MTMsImlzcyI6ImFwaUtleTEiLCJhdWQiOiJhcGlTZXJ2aWNlIiwic3ViIjoiYXBpS2V5MSJ9._6L_Ff29p9AWHLLZ-jEZdihy-H1glooSq_z162VKghA"
```

**构建并启动身份验证服务器**

1.切换到身份验证服务器目录：

```bash
cd ~/microservices-june/microservices-june-2023-auth/apiserver
```

2.构建身份验证服务器的 Docker 镜像（注意最后的句号）：

```bash
docker build -t apiserver .
```

3.启动身份验证服务器，并确认它正在运行（为方便阅读，输出结果分成了多行）：

```bash
docker run -d -p 80:80 apiserver
docker ps
CONTAINER ID   IMAGE       COMMAND                  ...
2b001f77c5cb   apiserver   "nginx -g 'daemon of..." ...  


    ... CREATED         STATUS          ...                                    
    ... 26 seconds ago  Up 26 seconds   ... 


    ... PORTS                                      ...
    ... 0.0.0.0:80->80/tcp, :::80->80/tcp, 443/tcp ...


    ... NAMES
    ... relaxed_proskuriakova
```

**测试身份验证服务器**

1.验证身份验证服务器是否拒绝没有 JWT 的请求，返回 401 Authorization Required：

```bash
curl -X GET http://localhost
<html>
<head><title>401 Authorization Required</title></head>
<body>
<center><h1>401 Authorization Required</h1></center>
<hr><center>nginx/1.23.3</center>
</body>
</html>
```

2.使用 Authorization 请求头提供 JWT。200 OK 返回状态码表明 API 客户端应用身份验证成功。

```bash
curl -i -X GET -H "Authorization: Bearer `cat $HOME/microservices-june/microservices-june-2023-auth/apiclient/token1.jwt`" http://localhost
HTTP/1.1 200 OK
Server: nginx/1.23.2
Date: Day, DD Mon YYYY hh:mm:ss TZ
Content-Type: text/html
Content-Length: 64
Last-Modified: Day, DD Mon YYYY hh:mm:ss TZ
Connection: keep-alive
ETag: "63dc0fcd-40"
X-MESSAGE: Success wtang
Accept-Ranges: bytes


{ "response": "success", "authorized": true, "value": "999" }
```

## 挑战 1：将Secrets硬编码至应用（不可以！）

在开始这个挑战之前，需要明确一点：将密钥硬编码至应用是一个糟糕的主意！您会发现任何可访问容器镜像的人员都能够轻松地找到并提取硬编码凭证。

在这个挑战中，您需要将 API 客户端应用的代码复制到 build 目录中，构建并运行该应用，然后提取密钥。

### 复制 API 客户端应用

apiclient 目录下的 app_versions 子目录中包含了一个简单 API 客户端应用的不同版本，这些版本将分别用于四个挑战，并且随着版本的升级安全性能逐步提高（详情请见“教程概述”）。

1.切换到 API 客户端目录：

```bash
cd ~/microservices-june/microservices-june-2023-auth/apiclient
```

2.将该挑战会用到的应用（采用硬编码Secret的应用）复制到工作目录下：

```bash
cp ./app_versions/very_bad_hard_code.py ./app.py
```

3.检查应用（注意将jwt的内容换成你自己的！）：

```bash
cat app.py
import urllib.request
import urllib.error

jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNpZ24ifQ.eyJpYXQiOjE2NzUyMDA4MTMsImlzcyI6ImFwaUtleTEiLCJhdWQiOiJhcGlTZXJ2aWNlIiwic3ViIjoiYXBpS2V5MSJ9._6L_Ff29p9AWHLLZ-jEZdihy-H1glooSq_z162VKghA"
authstring = "Bearer " + jwt
req = urllib.request.Request("http://host.docker.internal")
req.add_header("Authorization", authstring)
try:
    with urllib.request.urlopen(req) as response:
        the_page = response.read()
        message = response.getheader("X-MESSAGE")
        print("200  " + message)
except urllib.error.URLError as e:
    print(str(e.code) + " s " + e.msg)
```

该代码只向本地主机发送请求，并生成成功消息或失败状态码。

该请求在此行中添加了 Authorization 请求头：

```python
req.add_header("Authorization", authstring)
```

您还注意到了什么？是否看到了一个硬编码的 JWT？稍后我们会谈到这一点。首先，让我们构建并运行应用。

### 构建并运行 API 客户端应用

我们会用到 docker compose 命令和 Docker Compose YAML 文件——这有助于我们轻松了解运行状况。

（**注**：在上一节的第二步中，您已将挑战 1 会用到的 API 客户端应用的 Python 文件 (very_bad_hard_code.py) 重命名为 app.py。在其他三个挑战中您也要这样做。使用 app.py 可以简化流程，因为您无需更改 Dockerfile。这也意味着您需要在 docker compose 命令中添加 --build 参数，以每次都强制重建容器）。

docker compose 命令可构建容器，启动应用，发起一个 API 请求，然后关闭容器，同时在控制台上显示 API 调用的结果。

输出结果倒数第二行上的 200 Success 状态码表明身份验证成功。wtang 值是进一步的确认，它表明身份验证服务器能够解码 JWT 中该名称的声明（在您的环境中，wtang应该被替换成您自己的名称）：

```bash
docker compose -f docker-compose.hardcode.yml up --build
...
apiclient-apiclient-1  | 200  Success wtang
apiclient-apiclient-1 exited with code 0
```

因此，硬编码凭证可在我们的 API 客户端应用正常运行，这并不奇怪。但安全吗？或许安全，因为容器在退出之前只运行该脚本一次，并且没有 shell?

但事实上，一点也不安全。

### 从容器镜像检索Secret

硬编码凭证可供任何能够访问容器镜像的人员查看，因为提取容器的文件系统易如反掌。

1.创建提取目录并转到该目录：

```bash
mkdir ~/extract
cd ~/extract
```

2.列出有关容器镜像的基本信息。--format 标记提高了输出结果的可读性（出于同样的原因，输出结果分成了两行）：

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}"
CONTAINER ID   NAMES                   IMAGE       ...
11b73106fdf8   apiclient-apiclient-1   apiclient   ...
ad9bdc05b07c   exciting_clarke         apiserver   ...

    ... CREATED          STATUS
    ... 6 minutes ago    Exited (0) 4 minutes ago
    ... 43 minutes ago   Up 43 minutes
```

3.提取最新的 apiclient 镜像为 .tar 文件。对于 <container_ID>，用上述输出结果中 CONTAINER ID 字段的值（在本教程中为*11b73106fdf8*）代替。

```bash
docker export -o api.tar <container_ID>
```

创建 api.tar 归档文件需要几秒钟的时间，其中包括容器的整个文件系统。一种查找Secrets的方法是提取整个归档文件并对其进行解析，但事实证明，可通过一种快捷方式迅速找到或许值得注意的内容，即使用 docker history 命令显示容器的历史记录。（这个快捷方式特别方便，它还可以帮助您在 Docker Hub 或其他容器注册表上查找可能没有 Dockerfile 而只有容器镜像的容器）。

4.显示容器的历史记录：

```bash
docker history apiclient
IMAGE         CREATED        ...
9396dde2aad0  8 minutes ago  ...                    
<missing>     8 minutes ago  ...   
<missing>     28 minutes ago ...  

    ... CREATED BY                          SIZE ... 
    ... CMD ["python" "./app.py"]           622B ...   
    ... COPY ./app.py ./app.py # buildkit   0B   ... 
    ... WORKDIR /usr/app/src                0B   ...   

    ... COMMENT
    ... buildkit.dockerfile.v0
    ... buildkit.dockerfile.v0
    ... buildkit.dockerfile.v0
```

输出行按时间倒序排列。从中可以看出，工作目录被设置为 /usr/app/src，然后复制并运行了应用的 Python 代码文件。由此可轻松地推断出该容器的核心代码库在 /usr/app/src/app.py 中，那么凭证很可能位于此处。

5.确定这点后，提取该文件：

```bash
tar --extract --file=api.tar usr/app/src/app.py
```

6.显示该文件的内容，这样我们就获取了对“安全”JWT 的访问权限：

```bash
cat usr/app/src/app.py
...
jwt="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNpZ24ifQ.eyJpYXQiOjE2NzUyMDA4MTMsImlzcyI6ImFwaUtleTEiLCJhdWQiOiJhcGlTZXJ2aWNlIiwic3ViIjoiYXBpS2V5MSJ9._6L_Ff29p9AWHLLZ-jEZdihy-H1glooSq_z162VKghA"
...
```

## 挑战 2：将Secrets作为环境变量传递（同样不可以！）

如果您已经学完 Microservices June 2023 的第一单元（将十二要素应用于微服务架构），那么便了解如何使用环境变量将配置数据传递给容器。如果您错过了，也无妨，完成注册后，即可点播观看。

在这个挑战中，您需要把Secrets作为环境变量传递。与挑战 1 中一样，我们也不推荐这种方法! 它不像硬编码Secrets那样糟糕，但也存在一些弱点。

可通过四种方法将环境变量传递给容器：

- 在 Dockerfile 中使用 ENV 语句进行变量替换（为所有构建的镜像设置变量）。例如：
  
  ```bash
  ENV PORT $PORT
  ```

- 在 docker run 命令上使用 ‑e 标记。例如：
  
  ```bash
  docker run -e PASSWORD=123 mycontainer
  ```

- 在 Docker Compose YAML 文件中使用environment key。

- 使用包含变量的 .env 文件。

在这个挑战中，您将使用环境变量来设置 JWT，并检查容器，以查看是否已暴露 JWT。

### 传递环境变量

1.返回 API 客户端目录：

```bash
cd ~/microservices-june/microservices-june-2023-auth/apiclient
```

2.将该挑战会用到的应用（使用环境变量的应用）复制到工作目录下，覆盖挑战 1 中的 app.py 文件：

```bash
cp ./app_versions/medium_environment_variables.py ./app.py
```

3.检查应用。在相关输出行中，Secret (JWT) 被作为本地容器中的环境变量读取：

```bash
cat app.py
...
jwt = ""
if "JWT" in os.environ:
    jwt = "Bearer " + os.environ.get("JWT")
...
```

4.如上所述，可通过多种方法将环境变量传递给容器。为了保持一致，我们继续使用 Docker Compose。显示 Docker Compose YAML 文件的内容，该文件使用environment key来设置 JWT 环境变量：

```bash
cat docker-compose.env.yml
---
version: "3.9"
services:
  apiclient:
    build: .
    image: apiclient
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - JWT
```

5.在不设置环境变量的情况下运行该应用。输出结果中倒数第二行的 401 Unauthorized 状态码证实身份验证失败，因为 API 客户端应用没有传递 JWT：

```bash
docker compose -f docker-compose.env.yml up --build
...
apiclient-apiclient-1  | 401  Unauthorized
apiclient-apiclient-1 exited with code 0
```

6.为了简单起见，在本地设置环境变量。此时可以这样做，因为这个安全问题并不是我们目前所关注的：

```bash
export JWT=`cat token1.jwt`
```

7.再次运行容器。现在测试成功了，系统显示了与挑战 1 相同的消息。

```bash
docker compose -f docker-compose.env.yml up --build
... 
apiclient-apiclient-1  | 200  Success wtang
apiclient-apiclient-1 exited with code 0
```

至少现在基础镜像中不含Secrets，我们可以在运行时更安全地传递它，但还是存在问题。

### 检查容器

1.显示有关容器镜像的信息，以获取 API 客户端应用的容器 ID（为方便阅读，输出结果分成了两行）：

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}"
CONTAINER ID   NAMES                   IMAGE      ...
6b20c75830df   apiclient-apiclient-1   apiclient  ...
ad9bdc05b07c   exciting_clarke         apiserver  ...


    ... CREATED             STATUS
    ... 6 minutes ago       Exited (0) 6 minutes ago
    ... About an hour ago   Up About an hour
```

2.检查 API 客户端应用的容器。对于 <container_ID>，用上述输出结果中 CONTAINER ID 字段的值（此处为*6b20c75830df*）代替。

您可以使用 docker inspect 命令检查所有启动的容器，无论它们是否正在运行。但问题是，即使容器没有在运行，输出也会在 Env 阵列中暴露 JWT，将其不安全地保存在容器配置中。

```bash
docker inspect <container_ID>
...
"Env": [
  "JWT=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNpZ24ifQ.eyJpYXQiOjE2NzUyMDA...",
  "PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  "LANG=C.UTF-8",
  "GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D",
  "PYTHON_VERSION=3.11.2",
  "PYTHON_PIP_VERSION=22.3.1",
  "PYTHON_SETUPTOOLS_VERSION=65.5.1",
  "PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/1a96dc5acd0303c4700e026...",
  "PYTHON_GET_PIP_SHA256=d1d09b0f9e745610657a528689ba3ea44a73bd19c60f4c954271b790c..."
```

## 挑战 3：使用本地Secrets

现在您已经知道，硬编码Secrets和使用环境变量并不能满足您（或您的安全团队）的安全需求。

为了提高安全防护，您可以尝试使用本地 Docker Secrets来存储敏感信息。同样地，虽然这不是黄金标准方法，但可以了解一下其工作原理。即使您在生产环境中不使用 Docker，也要知道如何加大从容器中提取Secrets的难度。

在 Docker 中，Secrets通过文件系统 mount /run/secrets/ 暴露给容器，其中有个单独文件包含了每个Secret的值。

在这个挑战中，您使用 Docker Compose 将本地存储的Secret传递给容器，然后验证在使用这个方法时，该Secret在容器中是否不可见。

### 将本地存储的Secret传递给容器

1.如您所料，首先切换到 apiclient 目录：

```bash
cd ~/microservices-june/microservices-june-2023-auth/apiclient
```

2.将该挑战会用到的应用（使用容器内密钥的应用）复制到工作目录下，覆盖挑战 2 中的 app.py 文件：

```bash
cp ./app_versions/better_secrets.py ./app.py
```

检查 Python 代码，它从 /run/secrets/jot 文件中读取 JWT 值。

```bash
cat app.py
...
jotfile = "/run/secrets/jot"
jwt = ""
if os.path.isfile(jotfile):
    with open(jotfile) as jwtfile:
        for line in jwtfile:
            jwt = "Bearer " + line
...
```

这里我们要确保jwt文件只有一行，所以我们需要删除隐藏在行尾的换行符。您可以使用以下这个命令：

```bash
echo -n $(cat token1.jwt) > token1.jwt
```

最好cat一下确保没有换行符。

```bash
root@auth:~/microservices-june/microservices-june-2023-auth/apiclient # cat token1.jwt
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkYXRhIjpbeyJ0b29sdHQiOiJodHRwczovL3Rvb2x0dC5jb20ifV0sImlhdCI6MTY4MzAyMTAxOSwiZXhwIjoxNzE0NTc5MTk5LCJhdWQiOiIiLCJpc3MiOiJOR0lOWCIsInN1YiI6Ind0YW5nIn0.3v0plqdGVcppD6WCEOFV2o_IOygzbOR-soqKbK07l3Aroot@auth:~/microservices-june/microservices-june-2023-auth/apiclient #
```

我们将如何创建这个Secret呢？答案就在 docker-compose.secrets.yml 文件中。

3.检查 Docker Compose 文件，其中Secret文件在secrets部分中进行定义，然后被 apiclient 服务引用：

```bash
cat docker-compose.secrets.yml
---
version: "3.9"
secrets:
  jot:
    file: token1.jwt
services:
  apiclient:
    build: .
    extra_hosts:
      - "host.docker.internal:host-gateway"
    secrets:
      - jot
```

### 验证Secret是否在容器中不可见

1.运行该应用。因为我们已将 JWT 设为可在容器中访问，现在身份验证成功，并显示了一条熟悉的消息：

```bash
docker compose -f docker-compose.secrets.yml up --build
...
apiclient-apiclient-1  | 200 Success wtang
apiclient-apiclient-1 exited with code 0
```

2.显示有关容器镜像的信息，注意 API 客户端应用的容器 ID（有关输出示例，请参见挑战 2 中“检查容器”的第一步）：

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}"
```

3.检查面向 API 客户端应用的容器。对于 <container_ID>，用上一步输出中 CONTAINER ID 字段的值代替。不同于“检查容器”中第二步的输出，Env 部分的开头没有 JWT= 行：

```bash
docker inspect <container_ID>
"Env": [
  "PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  "LANG=C.UTF-8",
  "GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D",
  "PYTHON_VERSION=3.11.2",
  "PYTHON_PIP_VERSION=22.3.1",
  "PYTHON_SETUPTOOLS_VERSION=65.5.1",
  "PYTHON_GET_PIP_URL=https://github.com/pypa/get-pip/raw/1a96dc5acd0303c4700e026...",
  "PYTHON_GET_PIP_SHA256=d1d09b0f9e745610657a528689ba3ea44a73bd19c60f4c954271b790c..."
]
```

目前一切进展顺利，但我们的Secret位于容器文件系统中的 /run/secrets/jot。也许我们可以使用与挑战 1 中“从容器镜像检索密钥”相同的方法从该文件系统提取密钥。

4.切换到提取目录（您在挑战 1 中创建的），并将容器导出到 tar 归档文件：

```bash
cd ~/extract
docker export -o api2.tar <container_ID>
```

5.查找tar文件中包含的Secret:

```bash
tar tvf api2.tar | grep jot
-rwxr-xr-x  0 0      0           0 Mon DD hh:mm run/secrets/jot
```

哎呀，包含 JWT 的文件可见。我们不是说将Secret嵌入容器中是“安全的”吗？情况和挑战 1 中一样糟糕吗？

6.让我们来看看。从 tar 文件中提取Secret文件，并检查其内容：

```bash
tar --extract --file=api2.tar run/secrets/jot
cat run/secrets/jot
```

好消息！cat 命令没有输出，这意味着容器文件系统中的 run/secrets/jot 文件是空的，在那里看不到Secret！即使我们的容器中有Secrets工件，Docker 也不会在容器中存储任何敏感数据。

然而，虽然这种容器配置是安全的，但也有一个缺点。那就是当您运行容器时，本地文件系统中必须有一个名为 token1.jwt 的文件。如果您重命名该文件，则无法重新启动容器。（您可以亲自试试：重命名**而不是删除**token1.jwt，然后再从第一步运行 docker compose 命令。）

现在我们已经成功了一半：容器在使用Secrets时可确保Secrets不会被轻易窃取，但Secrets在主机上仍然不受保护。您肯定不希望Secrets以未加密的方式存储在纯文本文件中。现在是时候引入Secrets管理工具了。

## 挑战 4：使用Secrets Manager

Secrets Manager可帮助您在整个生命周期内管理、检索和轮换Secrets。现有很多Secrets Manager可供选择并能够实现类似的目的。

- 安全地存储Secrets
- 控制访问
- 在运行时分发Secrets
- 支持Secrets轮换

您可以使用以下Secrets管理选项：

- 云提供商Secrets服务（例如 AWS Secrets Manager、Google 云平台的Secrets Manager和 Microsoft Azure 的 Key Vault）
- Kubernetes Secret对象
- Hashicorp Vault——一个常用的跨平台Secrets Manager
- OpenShift Secrets管理服务
- Docker Swarm Secrets服务

为了简单起见，本挑战使用了 Docker Swarm，对于许多Secrets Manager来说，其工作原理相同。

在这个挑战中，您需要在 Docker 中创建Secrets，复制Secrets和 API 客户端代码，部署容器，然后查看您能否提取和轮换Secrets。

### 配置 Docker 密钥

1.同样切换到 apiclient 目录：

```bash
cd ~/microservices-june/microservices-june-2023-auth/apiclient
```

2.初始化 Docker Swarm：

```bash
docker swarm init
Swarm initialized: current node (t0o4eix09qpxf4ma1rrs9omrm) is now a manager.
...
```

3.从token1.jwt文件创建Secret：

```bash
docker secret create jot ./token1.jwt
qe26h73nhb35bak5fr5east27
```

4.显示有关该Secret的信息。注意Secret值 (JWT) 本身不显示：

```bash
docker secret inspect jot
[
  {
    "ID": "qe26h73nhb35bak5fr5east27",
    "Version": {
      "Index": 11
    },
    "CreatedAt": "YYYY-MM-DDThh:mm:ss.msZ",
    "UpdatedAt": "YYYY-MM-DDThh:mm:ss.msZ",
    "Spec": {
      "Name": "jot",
      "Labels": {}
    }
  }
]
```

### 使用 Docker Secret

在 API 客户端应用代码中使用 Docker Secret的方式与使用本地创建的Secret完全相同——您可以从 /run/secrets/ 文件系统中读取该Secret，只需更改 Docker Compose YAML 文件中的Secret限定符即可。

1.检查 Docker Compose YAML 文件。注意external字段中的值为 true，表明我们正在使用 Docker Swarm Secret：

```bash
cat docker-compose.secretmgr.yml
---
version: "3.9"
secrets:
  jot:
    external: true
services:
  apiclient:
    build: .
    image: apiclient
    extra_hosts:
      - "host.docker.internal:host-gateway"
    secrets:
      - jot
```

这样，该 Compose 文件应可以与我们现有的 API 客户端应用代码配合使用了。虽然 Docker Swarm（或任何其他容器编排平台）带来了许多额外的好处，但也加剧了复杂性。

由于 docker compose 不能与外部Secret一起使用，因此我们必须使用一些 Docker Swarm 命令，特别是 docker stack deploy。Docker Stack 隐藏了控制台输出，所以我们必须把输出写入日志，然后检查日志。

为了简化操作，我们还使用了一个连续的 while True 循环来确保容器持续运行。

2.将该挑战的应用（使用Secrets Manager的应用）复制到工作目录下，覆盖挑战 3 中的 app.py 文件。显示 app.py 的内容，我们可以看到代码与挑战 3 中的代码几乎相同。唯一的区别是添加了 while True 循环：

```bash
cp ./app_versions/best_secretmgr.py ./app.py
cat ./app.py
...
while True:
    time.sleep(5)
    try:
        with urllib.request.urlopen(req) as response:
            the_page = response.read()
            message = response.getheader("X-MESSAGE")
            print("200 " + message, file=sys.stderr)
    except urllib.error.URLError as e:
        print(str(e.code) + " " + e.msg, file=sys.stderr)
```

### 部署容器并检查日志

1.构建容器（在上述挑战中使用 Docker Compose 进行构建）：

```bash
docker build -t apiclient .
```

2.部署容器：

```bash
docker stack deploy --compose-file docker-compose.secretmgr.yml secretstack
Creating network secretstack_default
Creating service secretstack_apiclient
```

3.列出运行容器，注意 secretstack_apiclient 的容器 ID（同上，为方便阅读，输出结果分成了多行）。

```bash
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}"
CONTAINER ID  ...  
20d0c83a8b86  ... 
ad9bdc05b07c  ... 

    ... NAMES                                             ...  
    ... secretstack_apiclient.1.0e9s4mag5tadvxs6op6lk8vmo ...  
    ... exciting_clarke                                   ...                                 

    ... IMAGE              CREATED          STATUS
    ... apiclient:latest   31 seconds ago   Up 30 seconds
    ... apiserver          2 hours ago      Up 2 hours
```

显示 Docker 日志文件；对于 <container_ID>，用上一步输出中 CONTAINER ID 字段的值（此处为 20d0c83a8b86）代替。日志文件显示了一系列的成功消息，因为我们为应用代码中添加了 while True 循环。按下 Ctrl+c 退出命令。

```bash
docker logs -f <container_ID>
200 Success wtang
200 Success wtang
200 Success wtang
200 Success wtang
200 Success wtang
200 Success wtang
...
^c
```

### 尝试访问Secret

可以发现没有设置敏感的环境变量（但您可以像在挑战 2 中“检查容器”的第二步那样，使用 docker inspect 命令进行检查）。

从挑战 3 中我们还知道，/run/secrets/jot 文件为空，但您可以检查：

```bash
cd ~/extract
docker export -o api3.tar <container_ID>
tar --extract --file=api3.tar run/secrets/jot
cat run/secrets/jot
```

成功！您无法从容器中获取Secret，也无法直接从 Docker 密钥中读取Secret。

### 轮换Secret

当然，如果拥有合适的权限，我们还可以创建服务，并将其配置为将Secret读入日志或将其设置为环境变量。此外，您可能已经注意到，我们的 API 客户端和服务器之间的通信没有加密（纯文本）。

由此可见，无论使用何种Secrets管理系统，都有可能发生Secrets泄露。降低Secrets泄露几率的一种方法是定期轮换（更换）Secrets。

如果使用 Docker Swarm，则只能删除然后重新创建Secrets（Kubernetes 允许动态更新Secrets）。但您无法删除附加到运行中服务的Secrets。

1.列出正在运行的服务：

```bash
docker service ls
ID             NAME                    MODE         ... 
sl4mvv48vgjz   secretstack_apiclient   replicated   ... 


    ... REPLICAS   IMAGE              PORTS
    ... 1/1        apiclient:latest
```

2.删除 secretstack_apiclient 服务。

```bash
docker service rm secretstack_apiclient
```

3.删除该Secret并使用新令牌重新创建密钥（重新生成一个jwt并保存为token2.jwt，注意使用不同的Subject，最简单的方法就是加个2）：

```bash
docker secret rm jot
cd ~/microservices-june/microservices-june-2023-auth/apiclient
docker secret create jot ./token2.jwt
```

4.重新创建服务：

```bash
docker stack deploy --compose-file docker-compose.secretmgr.yml secretstack
```

5.查找 apiclient 的容器 ID（关于输出示例，请见“部署容器并检查日志”中的第三步）：

```bash
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}"
```

6.显示 Docker 日志文件，该文件显示了一系列的成功消息。对于 <container_ID>，用上一步输出中 CONTAINER ID 字段的值代替。按下 Ctrl+c 退出命令。

```bash
docker logs -f <container_ID>
200 Success wtang2
200 Success wtang2
200 Success wtang2
200 Success wtang2
...
^c
```

看到从wtang1变成了wtang2吗？您已成功轮换Secret。

在本教程中，API 服务器仍会同时接受这两个 JWT，但在生产环境中，您可以通过要求 JWT 中的声明具有某些值或检查 JWT 的到期日期来弃用旧 JWT。

还请注意，如果您使用的Secrets系统允许Secrets更新，那么您的代码就需要频繁地重新读取Secrets，以提取新的Secrets值。

## 清理

清理您在本教程中所创建的对象：

1.删除 secretstack_apiclient 服务。

```bash
docker service rm secretstack_apiclient
```

2.删除Secrets。

```bash
docker secret rm jot
```

3.终止 swarm（假设您只是为本教程创建了一个 swarm）。

```bash
docker swarm leave --force
```

4.关闭正在运行的 apiserver 容器。

```bash
docker ps -a | grep "apiserver" | awk {'print $1'} |xargs docker kill
```

5.列出并删除不需要的容器。

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}"
docker rm <container_ID>
```

6.列出并删除任何不需要的容器镜像。

```bash
docker image list   
docker image rm <image_ID>
```

# 实验完成
