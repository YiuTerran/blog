---
title: Cicd搭建笔记
description:
toc: true
authors: ["tryao"]
tags: ["devops"]
categories: []
collections: []
date: 2025-09-29T11:56:08+08:00
featuredVideo:
featuredImage:
draft: false
---

# 安装Docker

所有组件使用docker/docker compose搭建，所以先要安装docker。

docker安装过程略过，配置`/etc/docker/daemon.json`如下：

```json
{
  "data-root": "/data/docker",
  "bip": "192.168.100.1/24",
  "default-address-pools": [
    {"base": "192.168.0.0/16", "size": 24}
  ],
  "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.xuanyuan.me"
    ],
    "live-restore": true,
    "log-driver":"json-file",
    "log-opts": {"max-size":"50m", "max-file":"3"}

}
```

其中`data-root`一般调整到外挂磁盘；如果服务器的ip段是172段，需要修改bip到192段或者10段。

`live-restore`可以保证重启docker不重启容器（有时候需要关掉这个行为）。

# 搭建gitlab

首先需要搭建代码仓库，compose文件如下：

```yaml
services:
  gitlab:
    image: registry.gitlab.cn/omnibus/gitlab-jh
    container_name: gitlab
    restart: always
    hostname: 'zop-tools.cscec3b-iti.com'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://zop-tools.cscec3b-iti.com:7440'
        gitlab_rails['trusted_proxies']=['172.18.0.0/16']
        gitlab_rails['gitlab_port'] = 7440
        gitlab_rails['gravatar_enabled'] = false
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
        nginx['redirect_http_to_https'] = false
        nginx['proxy_set_headers'] = {
          "X-Forwarded-Proto" => "https",
          "X-Forwarded-Ssl" => "on",
          "X-Forwarded-Port" => "7440"
        }
    ports:
      - '7440:80'
    volumes:
      - '/data/gitlab/config:/etc/gitlab'
      - '/data/gitlab/logs:/var/log/gitlab'
      - '/data/gitlab/data:/var/opt/gitlab'
    shm_size: '256m'
```

* hostname和external_url修改成对外的域名。

* trusted_proxies对应的是外围nginx的地址。

* gitlab_port改成外部监听的端口。
* volumes需要手动先创建好

这里面的nginx是gitlab自带的nginx的配置。如果外围自己又加了个nginx，路径是：nginx(自建) -> nginx(gitlab) ->rails，这里面的转发header和外围nginx要对齐。

外围nginx的参考配置如下：

```nginx
upstream gitlab {
	server 172.18.195.26:7440;
}

server {
	server_name zop-tools.cscec3b-iti.com 171.43.173.112;
	listen 7440 ssl;

        ssl_certificate /etc/nginx/certs/cscec3b-iti.com.pem;
        ssl_certificate_key /etc/nginx/certs/cscec3b-iti.com.key;
        ssl_protocols TLSv1.1 TLSv1.2;
        ssl_session_cache shared:GITLAB:10m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://gitlab;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host:$server_port;
        proxy_set_header X-Forwarded-Ssl on;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_redirect off;
        proxy_connect_timeout 300;
        proxy_read_timeout 300;
        proxy_send_timeout 300;

        client_max_body_size 5m;
    }

    # 处理WebSocket连接
    location /websocket/ {
        proxy_pass http://gitlab;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

gitlab也支持高可用搭建，步骤就比较繁琐了（主要是通过PostgreSQL支持多节点），这里不记录。

# 搭建Gitlab runner

使用管理员账号登录gitlab，点击【管理员】按钮，进入【Runner】，点击【创建实例Runner】。

为Runner创建标签，ci文件中通过标签与Runner匹配，可以为某个Runner勾选【运行未打标签的作业】做兜底。

如果是虚拟机/裸金属服务器作为Runner，一台机器上装1个就可以了。

如果是k8s中安装Runner，整个集群里面装1个就行，这两种方式的工作原理不太一样，但都是有一个主进程周期探测有没有部署任务，有的话创建一个容器运行对应的任务。

创建完成后会显示密钥，复制它，后面会用上。

## Docker安装Runner

首先创建一个config文件夹，放入runner的配置`config.toml`，参考如下：

```toml
concurrent = 8
check_interval = 5
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "ecs"
  url = "https://zop-tools.cscec3b-iti.com:7440"
  id = 3
  token = "" #上面的密钥
  token_obtained_at = 2025-09-23T08:08:03Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  request_concurrency = 4
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.feature_flags]
    FF_USE_ADAPTIVE_REQUEST_CONCURRENCY = true
  [runners.docker]
    tls_verify = false
    image = "docker:26"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
    extra_hosts = ["zop-tools.cscec3b-iti.com:172.18.195.25"]
    shm_size = 0
    network_mtu = 0
```

由于CI进程里面一般需要使用docker进行镜像打包，而runner本身也要运行在docker里面。所以需要调用宿主机的docker来创建容器，从而避免docker in docker问题，因此需要再volumes里面做一层映射。当然还有个方案是使用其他工具打包（下面会讲）。

这里[runners.docker]里面的image可以随便写，因为ci文件那边可以覆盖掉。extra_hosts里面主要需要讲harbor镜像仓库的域名映射成内网地址，加快拉取速度。concurrent根据机器cpu核数适当挑战。

启动Runner的compose文件参考：

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner
    restart: always
    extra_hosts:
      - "zop-tools.cscec3b-iti.com:172.18.195.25"
    volumes:
      - /data/gitlab/runner/config:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=Asia/Shanghai
```

上面的config.toml要放到/data/gitlab/runner/config文件夹下面。

启动容器之后，gitlab那边可以看到runner上线。

## K8s安装Runner

k8s使用helm安装：

```bash
helm repo add gitlab https://charts.gitlab.cn
kubectl create ns gitlab-runner
```

假设将runner安装在`gitlab-runner`这个ns，服务使用`dev`和`test`两个ns进行部署，对应开发和测试环境。需要创建一个ServiceAccout给runner使用，赋予runner调用k8s api的权利。

```yaml
# 1. 在 gitlab-runner namespace 创建 ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-deployer
  namespace: gitlab-runner
---
# 2. 定义一个 ClusterRole，拥有所有资源的所有操作权限
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dev-test-full-access
rules:
- apiGroups: [ "*" ]
  resources: [ "*" ]
  verbs: [ "*" ]
---
# 3. 在 dev namespace 绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-deployer-dev
  namespace: dev
subjects:
- kind: ServiceAccount
  name: gitlab-deployer
  namespace: gitlab-runner
roleRef:
  kind: ClusterRole
  name: dev-test-full-access
  apiGroup: rbac.authorization.k8s.io
---
# 4. 在 gitlab-runner namespace 绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-deployer-test
  namespace: test
subjects:
- kind: ServiceAccount
  name: gitlab-deployer
  namespace: gitlab-runner
roleRef:
  kind: ClusterRole
  name: dev-test-full-access
  apiGroup: rbac.authorization.k8s.io
---
# 4. 在 test namespace 绑定
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitlab-deployer-self
  namespace: gitlab-runner
subjects:
- kind: ServiceAccount
  name: gitlab-deployer
  namespace: gitlab-runner
roleRef:
  kind: ClusterRole
  name: dev-test-full-access
  apiGroup: rbac.authorization.k8s.io

```

使用`kubectl apply -f account.yml`，在集群中创建权限和绑定。这里给的权限比较大，也可以修改ClusterRole里面的rules只赋予必要的权限。

之后创建values.yml，修改helm安装runner的默认配置：

```yaml
# 使用helm在k8s里面安装gitlab-runner
gitlabUrl: "https://zop-tools.cscec3b-iti.com:7440"
runnerRegistrationToken: "" #从gitlab中获取
runnerName: "k8s-gitlab-runner"
runnerTagList: "k8s,dev,test"
concurrent: 10 #并发度
checkInterval: 5
unregisterRunners: true

rbac:
  create: false
  serviceAccount: "gitlab-deployer"
  clusterWideAccess: false

runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "gitlab-runner"
        service_account = "gitlab-deployer"
        ttlSecondsAfterFinished = 300
        image = "ubuntu:22.04"
      [runners.cache]
        type = "s3"
        [runners.cache.s3]
        [runners.cache.gcs]

```

这里只需要绑定手动创建的ServiceAccount即可。

使用`helm install gitlab-runner gitlab/gitlab-runner -f values.yaml --namespace gitlab-runner`，完成runner安装，同样在gitlab里面会看到runner在线。

# 安装Harbor

harbor官方支持docker-compose安装，直接去github的release里面下载。

解压之后修改harbor.yml，主要需要修改的部分如下：

```yaml
http:
  port: 7441
external_url: https://zop-tools.cscec3b-iti.com:7441
harbor_admin_password: yourpass
data_volume: /data/harbor/data
trivy:
  ignore_unfixed: false
  skip_update: true
  skip_java_db_update: true
  offline_scan: true
  security_check: vuln
  insecure: false
```

**注意**：harbor会启动多个容器，其中redis和postgresql的名字可能会和已有的容器冲突，可以使用docker rename修改已有容器的名字。



之后运行`./install.sh --with-trivy`进行安装。

然后去github下载oras二进制文件，放到PATH下面，运行下面的脚本下载漏洞库：

```bash
#!/usr/bin/bash
#创建缓存目录
mkdir -p /data/harbor/data/trivy-adapter/trivy/{db,java-db}
cd /data/harbor/data/trivy-adapter/trivy

# 清空 db 目录下的内容
rm -rf db/*
# 清空 java-db 目录下的内容
rm -rf java-db/*

# 下载离线库文件
oras pull ghcr.nju.edu.cn/aquasecurity/trivy-java-db:1
oras pull ghcr.nju.edu.cn/aquasecurity/trivy-db:2

# 解压 jdb.tar.gz 文件到 java-db 目录
tar -xvf javadb.tar.gz -C java-db

# 解压 db.tar.gz 文件到 db 目录
tar -xvf db.tar.gz -C db

# 删除压缩包文件
rm -f javadb.tar.gz
rm -f db.tar.gz

#chown赋权
chown -Rf 10000:10000 /data/harbor/data/trivy-adapter/trivy
```

可以在cronjob里面配置每天更新漏洞库。

之后就可以在harbor里面进行镜像管理和漏洞扫描了。

harbor外侧的nginx配置参考：

```nginx
upstream harbor {
	server 172.18.195.26:7441;
}

server {
	server_name zop-tools.cscec3b-iti.com 171.43.173.112;
	listen 7441 ssl;

        ssl_certificate /etc/nginx/certs/cscec3b-iti.com.pem;
        ssl_certificate_key /etc/nginx/certs/cscec3b-iti.com.key;
        ssl_protocols TLSv1.1 TLSv1.2;
        ssl_session_cache shared:HARBOR:10m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://harbor;
    	  proxy_http_version 1.1;

        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_connect_timeout 300;
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        client_max_body_size 2000m;

        proxy_buffering on;
        proxy_pass_request_headers on;
    }

}
```

主要是要支持大镜像的拉取和推送。

# 安装nexus

由于ci运行在容器里无法复用宿主机的缓存，需要nexus做一层局域网缓存加快ci编译速度。

```yaml
services:
  nexus:
    image: sonatype/nexus3:latest
    container_name: nexus3
    restart: always
    ports:
      - "7442:8081"
    volumes:
      - /data/nexus/data:/nexus-data
    environment:
      - NEXUS_CONTEXT=/
      - INSTALL4J_ADD_VM_PARAMS=-Xms1g -Xmx4g -XX:MaxDirectMemorySize=4g -Djava.util.prefs.userRoot=/nexus-data/.java/.userPrefs
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8081/service/metrics/health"]
      interval: 30s
      timeout: 10s
      retries: 10
```

唯一需要注意的是参数里面jvm的内存分配，这玩意儿里面有es，内存建议不低于4g。

登录nexus，在settings-repositories里面手动创建npm的代理(proxy)和托管(hosted)。maven可以将中央仓库改为阿里源，增加google等常用proxy。

修改~/.m2/settings.xml，将仓库加到配置里，ci的时候也要将这个文件放到对应的位置。

外围nginx反向代理配置参考：

```nginx
server {
	server_name zop-tools.cscec3b-iti.com 171.43.173.112;
	listen 7442 ssl;

        ssl_certificate /etc/nginx/certs/cscec3b-iti.com.pem;
        ssl_certificate_key /etc/nginx/certs/cscec3b-iti.com.key;
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
        ssl_session_cache shared:HARBOR:10m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

       location /v2 {
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto "https";
        proxy_read_timeout 600;
        client_max_body_size 2000m;

        proxy_pass http://172.18.195.26:7442/repository/zop-image/$request_uri;
      }

      location / {
        proxy_pass http://172.18.195.26:7442;
    	  proxy_http_version 1.1;

        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_connect_timeout 300;
        proxy_read_timeout 300;
        proxy_send_timeout 300;
        client_max_body_size 2000m;

        proxy_buffering on;
        proxy_pass_request_headers on;
    }
}
```

这里`/v2`是给docker仓库用的，如果不想安装harbor，而是用nexus托管docker镜像，可以创建对应的仓库（这里叫zop-image），然后配置上去。

但是，nexus的docker托管不支持按aritifact清理镜像，也不支持trivis集成，不如harbor成熟。

# 安装SonarQube

如果想在ci时统一管控代码质量，可以安装sonar.

Docker Compose文件如下：

```yaml
services:
  sonarqube:
    image: sonarqube:community
    hostname: sonarqube
    container_name: sonarqube
    read_only: true
    extra_hosts:
      - "zop-tools.cscec3b-iti.com:172.18.195.25"
    depends_on:
      db:
        condition: service_healthy
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_temp:/opt/sonarqube/temp
    ports:
      - "7443:9000"
    networks:
      - ${NETWORK_TYPE:-ipv4}
  db:
    image: postgres:17
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}" ]
      interval: 10s
      timeout: 5s
      retries: 5
    hostname: postgresql
    container_name: postgresql
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - postgresql:/var/lib/postgresql
    networks:
      - ${NETWORK_TYPE:-ipv4}

volumes:
  sonarqube_data:
  sonarqube_temp:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql:

networks:
  ipv4:
    driver: bridge
    enable_ipv6: false
  dual:
    driver: bridge
    enable_ipv6: true
    ipam:
      config:
        - subnet: "192.168.2.0/24"
          gateway: "192.168.2.1"
        - subnet: "2001:db8:2::/64"
          gateway: "2001:db8:2::1"
```

需要注意的是，sonar不支持挂载volume，只能用docker create的volume，所以一定要在docker配置文件里修改data-root，避免磁盘溢出。

如果服务器可以连接github，可以在市场里面下载中文插件。否则需要手动下载jar包到`/data/docker/volumes/sonarqube_sonarqube_extensions/_data/plugins`， 这里data-root是`/data/docker`。

然后重启容器就会变成中文界面。

将sonar关联到gitlab也比较简单，在gitlab用户那边创建访问令牌，授权gitlab read相关api就可以了。

# 配置CI/CD

都安装完成之后，在gitlab里面创建一个cicd专用的项目，比如devops/cicd，可以设置为”内部“权限，或者公开权限（如果用了vpn的话），方便其他项目集成。

在项目根目录创建templates文件夹，然后将完善项目描述、ReadMe文件。

在项目根目录下创建`.gitlab-ci.yml`文件，内容如下：

```yaml
stages:
  - release
create-release:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  script: echo "Creating release $CI_COMMIT_TAG"
  rules:
  - if: $CI_COMMIT_TAG
  release:
    tag_name: $CI_COMMIT_TAG
    description: "Release $CI_COMMIT_TAG of components in $CI_PROJECT_PATH"

```

这样一旦给commit打了tag就会自动发布新版本。

在templates里面添加常用的模板供其他项目集成，比如java后端的编译+部署模板如下：

```yaml
variables:
  # 默认镜像制品名（可被项目覆盖）
  IMAGE_ARTIFACT_NAME: "$CI_PROJECT_NAME"
  # 默认容器名称
  CONTAINER_NAME: "app"

stages:
- build
- deploy

default:
  before_script:
  - |
    export IMAGE_TAG="$CI_COMMIT_SHORT_SHA"
    if [[ -n "$CI_COMMIT_TAG" ]]; then export IMAGE_TAG="$CI_COMMIT_TAG"; fi
    export IMAGE="$HARBOR_HOST/$REPO_NAME/$IMAGE_ARTIFACT_NAME:$IMAGE_TAG"
    echo "Built image will be: $IMAGE"

.kaniko_build:
  image:
    name: zop-tools.cscec3b-iti.com:7441/cicd/kaniko:debug
    entrypoint: [ "" ]
  script:
  - echo "{\"auths\":{\"${HARBOR_HOST}\":{\"auth\":\"$(echo -n ${HARBOR_USER}:${HARBOR_PWD} | base64)\"}}}" > /kaniko/.docker/config.json
  - /kaniko/executor --context ${CI_PROJECT_DIR} --dockerfile ${CI_PROJECT_DIR}/Dockerfile --destination ${IMAGE}

# 使用kaniko构建镜像（dev/test）
dev_test_build:
  stage: build
  extends: .kaniko_build
  rules:
  - if: '$CI_COMMIT_BRANCH == "dev"'
    when: manual
    variables:
      REPO_NAME: "dev"
  - if: '$CI_COMMIT_BRANCH == "test"'
    variables:
      REPO_NAME: "test"
  tags: [ $CI_COMMIT_BRANCH ]

# 使用kaniko构建镜像（生产）
release_build:
  stage: build
  extends: .kaniko_build
  rules:
  - if: '$CI_COMMIT_TAG =~ /^v/'
    variables:
      REPO_NAME: "main"
  tags: [ "main" ]

# 部署到 Kubernetes（仅 dev/test 分支）
dev_test_deploy:
  stage: deploy
  image: zop-tools.cscec3b-iti.com:7441/cicd/kubectl:1.24
  script:
  - echo "Deploying $IMAGE to namespace $K8S_NAMESPACE"
  - kubectl set image deployment/$IMAGE_ARTIFACT_NAME $CONTAINER_NAME=$IMAGE -n $K8S_NAMESPACE
  - kubectl rollout status deployment/$IMAGE_ARTIFACT_NAME -n $K8S_NAMESPACE --timeout=300s
  rules:
  - if: '$CI_COMMIT_BRANCH == "dev"'
    when: manual
    variables:
      K8S_NAMESPACE: "dev"
      REPO_NAME: "dev"
  - if: '$CI_COMMIT_BRANCH == "test"'
    when: manual
    variables:
      K8S_NAMESPACE: "test"
      REPO_NAME: "test"
  needs: [ dev_test_build ]
  tags: [ $CI_COMMIT_BRANCH ]

```

这个CI/CD文件使用**kaniko进行编译打包**，并支持dev/test环境持续部署（替换镜像名）。

为了加快CI/CD的速度，这里将image都上传到私库里面了。

对于k8s的runner，**需要同时修改k8s宿主机的host和coredns的host，将域名映射成内网ip。**

**注**：google官方的kaniko已经不再维护，建议使用第三方维护的`martizih/kaniko`镜像，用debug版本（有bash）。

在对应的项目的`.gitlab-ci.yml`里，引用对应的模板即可：

```yaml
include:
  - project: 'devops/cicd'
    ref: v0.9.2
    file: 'templates/backend.yml'

# 可选：覆盖默认变量
variables:
  IMAGE_ARTIFACT_NAME: "hello-world"

```

这里面的ref对应release的版本，如果还在调试，可以用`main`引用最新的commit.

项目的Dockerfile可以参考：

```dockerfile
FROM zop-tools.cscec3b-iti.com:7441/cicd/openjdk:21-builder AS builder

# 设置工作目录
WORKDIR /app

# 复制 Maven 配置文件
COPY pom.xml .
# 下载依赖（利用 Docker 缓存）
RUN mvn dependency:go-offline -B

# 复制源代码
COPY src ./src

# 编译打包
RUN mvn package -DskipTests

# 第二阶段：运行环境
FROM zop-tools.cscec3b-iti.com:7441/cicd/openjdk:21

# 设置工作目录
WORKDIR /app

# 从 builder 阶段复制 jar 包
COPY --from=builder /app/target/*.jar app.jar

# 暴露端口
EXPOSE 8080

# 运行应用
ENTRYPOINT ["java", "-jar", "app.jar"]
```

注意这是一个多阶段Dockerfile，编译型语言需要在第一阶段构建出目标文件，解释型语言（如Python）一般不需要。

# 附：Docker镜像定制

docker镜像最小的一般是alpine版本，定制化的话需要替换国内源。如果是go/c++服务，尽量用glibc版本，musl版本有时候会有一些奇奇怪怪的问题。

glibc版本的alpine:

```dockerfile
FROM frolvlad/alpine-glibc:alpine-3.18_glibc-2.34

ENV TZ Asia/Shanghai

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk add --no-cache alpine-conf ttf-dejavu fontconfig \
    && /sbin/setup-timezone -z Asia/Shanghai \
    && apk del alpine-conf && rm -rf /tmp/* /var/cache/apk/*

```

一般的基于alpine的镜像定制（java21）：

```dockerfile
FROM azul/zulu-openjdk-alpine:21

ENV TZ Asia/Shanghai

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
    && apk add --no-cache alpine-conf ttf-dejavu fontconfig \
    && /sbin/setup-timezone -z Asia/Shanghai \
    && apk del alpine-conf && rm -rf /tmp/* /var/cache/apk/*

```

用的时候，直接用apk安装需要的二进制文件即可，例如`apk add curl`。
