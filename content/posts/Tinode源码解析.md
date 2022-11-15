---
title: Tinode源码解析
description:
toc: true
authors: ["tryao"]
tags: ["golang", "im", "tinode"]
categories: []
series: []
date: 2022-11-14T19:21:38+08:00
lastmod: 2022-11-14T19:21:38+08:00
featuredVideo:
featuredImage:
draft: true
---

## 概述

有朋友需要做一个im，简单做了一下技术调研，流行的开源框架包括：

* Tinode/chat: 即本文主角，golang编写，架构比较简单，有MySQL就能跑，轻量级方案。支持web/ios/android，界面长得比较像telegram；支持chatbot. 国内用有点水土不服，主要是推送等组件依赖国外大厂的服务(S3, Firebase等），国内根本连不上，需要自己改成个推之类的方案。由于方案比较轻量，消息可靠性上有一些缺陷，内置了chatbot支持（可以用Python写）；
* Open-IM-Server：据说是某个腾讯核心人员离职后自己开源的。服务端golang，架构基于微服务，有商业产品，自己试了一下目前版本大概有16个微服务，依赖kafka&zk、mysql、etcd、redis、miniIO和MongoDB。架构比较合理，早期是写扩散模型，v2.3之后群聊改为读扩散模型。主要问题是架构比较重，文档写的烂，需要自己分析代码，小团队维护比较吃力；且无chat bot相关设计；
* turms-im/turms：java写的，读扩散模型。maintainer比较有自信，号称开源界最先进的方案，文档确实写的不错，很详细的技术分析。不过star数不多，实际使用者估计也寥寥。而且作者喜欢自研，Log/注册中心/配置中心这些都是自研的…有种自嗨过了头的感觉。整体来讲架构比较中庸，技术细节把控的比较好。java团队可以考虑，代码还比较易读，而且没有商业版，作者没有恰饭需求；
* wildfirechat/im-server：也是java做的，主要卖商业版。亮点是基于protobuf+MQTT做的，协议设计上比较先进。由于主要卖商业版，所以开源生态一般般，愿意买商业版的可以考虑，好像价格还比较划算；
* Rocket.chat：应该是github上star数最多的IM软件了，基于nodeJS编写。面向B端，类似钉钉/Slack这种IM，有复杂B端需求的团队建议优先考虑。性能上就不要太指望了…毕竟nodejs比Python也快不到哪里去。主打的是丰富的功能和生态。

这几个项目是客户端生态做的最好的了，基本能开箱即用。其他一些如goim之类的，没有客户端只有服务器，那还不如用mqtt自己写一个，毕竟有emqx这种高性能broker，写一个im真不算啥难事。聊天存储用influxdb或者MongoDB，元数据存MySQL。设计好推拉模型，读写扩散，消息时序，topic规则，一个基本的im软件还是能很快成型的。

由于这次的需求是小团队，少量用户(<1w)聊天场景，需要机器人支持，目前就先用tinode试水。

## 安装

在github上fork一下chat项目，clone下来。install.md里面的安装指南也是错的，不用看，要跑起来准备一个MySQL5.7+的版本即可。MongoDB不支持集群，因此这里用MongoDB没啥优势，MySQL可以换成tidb.

在server文件夹下建立static文件夹，将`https://github.com/tinode/webapp/archive/master.zip`解压到static文件夹下。

修改build-all.sh，这个脚本bug挺多的，推测是有go mod之前用的，修改后仅保留windows和linux的两个二进制文件，mac可以自己加上darwin+amd64/arm64的配置，大致如下：

```bash
#!/bin/bash

# This script builds and archives binaries and supporting files for mac, linux, and windows.
# If directory ./server/static exists, it's asumed to contain TinodeWeb and then it's also
# copied and archived.

# Supported OSs: mac (darwin), windows, linux.
goplat=(windows linux)

# CPUs architectures: amd64 and arm64. The same order as OSs.
goarc=(amd64 amd64)

# Number of platform+architectures.
buildCount=${#goplat[@]}

# Supported database tags
dbtags=(mysql)

for line in "$@"; do
  eval "$line"
done

version=$1

if [ -z "$version" ]; then
  # Get last git tag as release version. Tag looks like 'v1.2.3', so strip 'v'.
  version=$(git describe --tags)
  version=${version#?}
fi

if [ -z "$version" ]; then
  version='0.0.1'
fi

echo "Releasing $version"

GOSRC=$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")

pushd "${GOSRC}"/chat >/dev/null || exit

# Prepare directory for the new release
rm -fR ./releases/"${version}"
mkdir -p ./releases/"${version}"

# Tar on Mac is inflexible about directories. Let's just copy release files to
# one directory.
rm -fR ./releases/tmp
mkdir -p ./releases/tmp/templ

# Copy templates and database initialization files
cp ./server/tinode.json5 ./releases/tmp
cp ./server/templ/*.templ ./releases/tmp/templ
cp ./tinode-db/data.json ./releases/tmp
cp ./tinode-db/*.jpg ./releases/tmp
cp ./tinode-db/credentials.sh ./releases/tmp

# Create directories for and copy TinodeWeb files.
if [[ -d ./server/static ]]; then
  mkdir -p ./releases/tmp/static/img
  mkdir ./releases/tmp/static/css
  mkdir ./releases/tmp/static/audio
  mkdir ./releases/tmp/static/src
  mkdir ./releases/tmp/static/umd

  cp ./server/static/img/*.png ./releases/tmp/static/img
  cp ./server/static/img/*.svg ./releases/tmp/static/img
  cp ./server/static/img/*.jpeg ./releases/tmp/static/img
  cp ./server/static/audio/*.m4a ./releases/tmp/static/audio
  cp ./server/static/css/*.css ./releases/tmp/static/css
  cp ./server/static/index.html ./releases/tmp/static
  cp ./server/static/index-dev.html ./releases/tmp/static
  cp ./server/static/version.js ./releases/tmp/static
  cp ./server/static/umd/*.js ./releases/tmp/static/umd
  cp ./server/static/manifest.json ./releases/tmp/static
  cp ./server/static/service-worker.js ./releases/tmp/static
  # Create empty FCM client-side config.
  touch ./releases/tmp/static/firebase-init.js
else
  echo "TinodeWeb not found, skipping"
fi

for ((i = 0; i < buildCount; i++)); do
  plat="${goplat[$i]}"
  arc="${goarc[$i]}"

  suffix=''
  if [ "$plat" = "windows" ]; then
    suffix='.exe'
  fi
  # Remove possibly existing keygen.
  rm -f ./releases/tmp/keygen*

  # Keygen is database-independent
  env GOOS="${plat}" GOARCH="${arc}" go build -ldflags "-s -w" -o ./releases/tmp/keygen"${suffix}" ./keygen >/dev/null

  for dbtag in "${dbtags[@]}"; do
    echo "Building ${dbtag}-${plat}/${arc}..."

    # Remove possibly existing binaries from earlier builds.
    rm -f ./releases/tmp/tinode"${suffix}"
    rm -f ./releases/tmp/init-db"${suffix}"

    env GOOS="${plat}" GOARCH="${arc}" go build \
      -ldflags "-s -w -X main.buildstamp=$(git describe --tags)" -tags "${dbtag}" \
      -o ./releases/tmp/tinode"${suffix}" ./server >/dev/null
    env GOOS="${plat}" GOARCH="${arc}" go build \
      -ldflags "-s -w" -tags "${dbtag}" -o ./releases/tmp/init-db"${suffix}" ./tinode-db >/dev/null

    # Build archive. All platforms but Windows use tar for archiving. Windows uses zip.
    if [ "$plat" = "windows" ]; then
      # Remove possibly existing archive.
      rm -f ./releases/"${version}/tinode-${dbtag}.${plat}-${arc}".zip
      # Generate a new one
      pushd ./releases/tmp >/dev/null || exit
      zip -q -r ../"${version}/tinode-${dbtag}.${plat}-${arc}".zip ./*
      popd >/dev/null || exit
    else
      # Remove possibly existing archive.
      rm -f ./releases/"${version}/tinode-${dbtag}.${plat}-${arc}".tar.gz
      # Generate a new one
      tar -C ./releases/tmp -zcf ./releases/"${version}/tinode-${dbtag}.${plat}-${arc}".tar.gz .
    fi
  done
done

# Build chatbot release
echo "Building python code..."

./build-py-grpc.sh

# Release chatbot
echo "Packaging chatbot.py..."
rm -fR ./releases/tmp
mkdir -p ./releases/tmp

cp "${GOSRC}"/chat/chatbot/python/chatbot.py ./releases/tmp
cp "${GOSRC}"/chat/chatbot/python/quotes.txt ./releases/tmp
cp "${GOSRC}"/chat/chatbot/python/requirements.txt ./releases/tmp

tar -C "${GOSRC}"/chat/releases/tmp -zcf ./releases/"${version}"/py-chatbot.tar.gz .
pushd ./releases/tmp >/dev/null || exit
zip -q -r ../"${version}"/py-chatbot.zip ./*
popd >/dev/null || exit

# Release tn-cli
echo "Packaging tn-cli..."

rm -fR ./releases/tmp
mkdir -p ./releases/tmp

cp "${GOSRC}"/chat/tn-cli/*.py ./releases/tmp
cp "${GOSRC}"/chat/tn-cli/*.txt ./releases/tmp

tar -C "${GOSRC}"/chat/releases/tmp -zcf ./releases/"${version}"/tn-cli.tar.gz .
pushd ./releases/tmp >/dev/null || exit
zip -q -r ../"${version}"/tn-cli.zip ./*
popd >/dev/null || exit

# Clean up temporary files
rm -fR ./releases/tmp

popd >/dev/null || exit
```

在平台上安装grpc相关依赖，包括protoc的二进制，以及：

```go
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

另外安装Python3环境，并pip安装如下依赖：

```
tinode-grpc>=0.20.0b3
grpcio==1.50.0
grpcio-tools==1.50.0
protobuf==4.21.9
six==1.16.0
```

这是给chatbot以及py_grpc这个包用的。

然后，在linux下运行build-all.sh即可，会在release文件夹下生成zip文件。

## 配置



