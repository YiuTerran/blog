---
title: K3s里安装rancher的坑
date: 2026-04-27T12:29:13+08:00
slug: 181f01c
draft: false
author:
  name: tryao
tags: []
collections: []
toc: true
math: true
lightgallery: false
---

用docker安装rancher很简单，但是用k3s/k8s安装rancher有点麻烦，这里记录一下遇到的问题。

<!--more-->

我这里需要在外部终止tls，不能走k3s的https。

首先是装k3s的时候的命令行，注意：

```bash
cat << EOF > /etc/default/k3s
CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=3650
EOF
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
INSTALL_K3S_SKIP_SELINUX_RPM=true \
K3S_KUBECONFIG_MODE="644" \
INSTALL_K3S_MIRROR=cn \
INSTALL_K3S_VERSION=v1.34.6+k3s1 \
sh -s - server \
  --docker \
  --cluster-init \
  --default-local-storage-path=/data/k3s
```

后续节点：

```bash
cat << EOF > /etc/default/k3s
CATTLE_NEW_SIGNED_CERT_EXPIRATION_DAYS=3650
EOF
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
INSTALL_K3S_SKIP_SELINUX_RPM=true \
K3S_KUBECONFIG_MODE="644" \
INSTALL_K3S_MIRROR=cn \
INSTALL_K3S_VERSION=v1.34.6+k3s1 \
K3S_TOKEN="<第一个节点查看/var/lib/rancher/k3s/server/node-token>" \
sh -s - server \
  --server https://<第一个节点ip>:6443 \
  --docker \
  --default-local-storage-path=/data/k3s
```

这里需要把证书改为10年有效期，省得总是续期。

然后修改了默认存储的位置。

通过helm安装rancher，需要注意虽然helm出了4，但是k3s目前只支持helm3。然后就是虽然k8s已经建议使用Gateway API，但是k3s默认仍然用ingress，且默认是关闭GatewayAPI的。

```bash
helm install rancher rancher-stable/rancher --namespace cattle-system --set hostname=<访问域名> --set bootstrapPassword=<初始密码> --set tls=external
```

在nginx处配置：

```nginx
upstream rancher {
        server 192.168.110.33:80;
        server 192.168.110.34:80;
        server 192.168.110.35:80;
}

map $http_upgrade $connection_upgrade {
    default Upgrade;
    ''      close;
}


server {
    listen 32004 ssl;
    http2 on;
    server_name <域名>;
    ssl_certificate /etc/nginx/certs/fullchain.cer;
    ssl_certificate_key /etc/nginx/certs/private.key;
    client_max_body_size 0;
    location / {
        proxy_pass http://rancher;

        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        proxy_read_timeout 1800s;
        proxy_send_timeout 1800s;
        proxy_connect_timeout 30s;
        proxy_buffering off;
    }
}
```

特别注意我这里没有用443，如果能用443可以省不少事。

然后要修改K3s默认的ingress配置：

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
      - "--entryPoints.web.forwardedHeaders.insecure=true"
      - "--entryPoints.websecure.forwardedHeaders.insecure=true"
```

这里是要信任上一层传过来的数据，不然请求80会重定向到443.
