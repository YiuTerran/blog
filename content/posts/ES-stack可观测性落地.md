---
title: ES Stack可观测性落地
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2022-10-12T17:52:42+08:00
lastmod: 2022-10-12T17:52:42+08:00
featuredVideo:
featuredImage:
draft: true
---

随着ES v8.4的发布，es对于可观测性三支柱（Metric/Trace/Log）都具有较为完备的支持，Alert功能也能满足一般需求，kibana的看板功能经过这么多年的迭代，可用性也比较好了。最重要的是，**兼容OpenTelemetry的标准**也保证如果用的不爽也可以用其他开源组件替换，所以项目组目前搭建监控平台，经过评估还是决定优先用这一套。

## ElasticSearch部分

### 安装ES

目前公司用的还是CentOS，所以用RPM安装就行，官方指南[地址](https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html).

另外ES已经支持k8s安装，有需要的话建议[使用](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html).

```sh
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

cat>/etc/yum.repos.d/elasticsearch.repo<<EOF
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md
EOF

sudo yum install -y --enablerepo=elasticsearch elasticsearch 
```

es应该是有中国的CDN，所以下载很快。在安装过程中会自动生成超管密码：

> The generated password for the elastic built-in superuser is : <xxxx>

默认安装的es是单机模式，如果想要加入已有的集群，则在该集群任意节点生成token：

```bash
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node
```

然后在这个新安装的节点上配置生成的token:

```bash
/usr/share/elasticsearch/bin/elasticsearch-reconfigure-node --enrollment-token <enrollment-token>
```

接着就可以启动服务了：

```bash
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service
sudo systemctl start elasticsearch.service
```

可以用以下命令确认es运行状态：

```bash
curl --cacert /etc/elasticsearch/certs/http_ca.crt -u elastic https://localhost:9200 
```

这里就输入刚才自动生成的密码即可。

如果是从旧版ES进行升级，ES只保证一个大版本的兼容性，所以从6.x只能先升级到7.x，然后再升级到8.x。甚至7.17之前的版本还要先升级到7.17才行。每个结点独立升级一般不影响服务可用性。特别注意的是大版本升级可能会影响Rest API的兼容性，所以一定要非常谨慎。

### 配置ES

所有配置集中在`/etc/elasticsearch`下面，该文件夹以及所有子文件的权限默认都是`root:elasticsearch`。JVM相关的配置在`/etc/sysconfig/elasticsearch`下，其他的配置则集中在`/etc/elasticsearch/elasticsearch.yml`中。二进制文件在`/usr/share/elasticsearch/bin`下，可以考虑加到PATH里。

使用systemd启动的服务，则需要配置systemd的资源限制，打开`/usr/lib/systemd/system/elasticsearch.service`可以看到默认的资源限制。如果不满足需求，可以通过`sudo systemctl edit elasticsearch`来生成覆盖配置，完事之后通过`sudo systemctl daemon-reload`重新加载配置即可生效。

es在安装时会自动生成CA证书，在`/etc/elasticsearch/certs`下，客户端所在的机器需要copy证书并信任，才能正常进行HTTPS通信。当然可以通过修改配置文件关掉集群间SSL通信，将`xpack.security.transport.ssl.enabled`改成false即可。

密码可以使用`bin/elasticsearch-keystore`工具从加密文件中重新获取。

ES可以通过`PUT /_cluster/settings`的API直接修改整个集群的配置，不必一台一台去改配置文件。只有一小部分需要通过手动修改配置文件指定（如集群的名字等）。es的配置项非常多，不过大部分保持默认即可，需要注意的主要是[这里](https://www.elastic.co/guide/en/elasticsearch/reference/current/important-settings.html).

尤其注意，一旦打开集群模式，即将`network.host`配置打开，es启动时就会进行严格自检，如果有不满足的配置，则无法正常启动。需要注意的点包括：

* 修改文件描述符限制；
* 关闭swap；
* 在`sysctl.conf`里面设置`vm.max_map_count=262144`；
* 调整最大线程数限制；
* 根据需求调整jvm dns设置，以及tcp重传超时设置；
* 确认/tmp文件夹允许执行二进制文件；

在配置完成之后，需要删除掉配置文件中的`cluster.initial_master_nodes`再重新启动。

另外，如果是单机启动，可以加上`discovery.type: single-node`。

可以通过设置

```yaml
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
```

关闭ssl加密通信，**但是最好别这么做**，因为下面的Fleet会强制使用SSL。

重启之后使用curl命令重新测试一下，保证配置文件没改错。

### 集群管理

这部分比较复杂，暂时先不管，后续追加笔记。默认情况下es安装后是开发模式，可以用来单节点做大部分测试了。

特别需要注意的是：**所有节点统一使用一套ssl证书，不要每个节点生成一个！**，把第一个节点的`/etc/elasticsearch/certs`copy到其他结点，然后重启es即可。

## Kibana部分

### 安装kibana

kibana版本要和es一致，方法也差不多，这里还是用rpm安装：

```bash
yum install --enablerepo=elasticsearch kibana
```

repo的地址和es是一致的，我们这里在同一台设备上安装，所以直接安装就行。

这里可以为kibana生成token，也可以生成用户名密码。推荐使用token。

token生成：

```bash
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
# 复制生成的token并
/usr/share/kibana/bin/kibana-setup --enrollment-token <token>
```

设置`kibana_system`的密码：

```bash
bin/elasticsearch-reset-password interactive -u kibana_system
```

这里会生成一个随机密码。

### 配置kibana

配置文件在/etc/kibana下，需要配置的一般包括：

```yaml
server.port: 5601
server.host: "0.0.0.0"
server.name: "your-system-name"
elasticsearch.hosts: []
# 用户名和密码或者token设置一个就可以，推荐使用密码
elasticsearch.username: "kibana_system"
# 刚才生成的密码
elasticsearch.password: "xxxx"
# 刚才复制的token
# elasticsearch.serviceAccountToken: ""
i18n.locale: "zh-CN"
# 外网访问地址，如果是有域名则配置域名，或者一般配置反代的地址
server.publicBaseUrl: "http://<out-ip>:5601"
```

改好之后通过`systemctl start kibana`启动服务，通过`journalctl -u kibana`查看日志，如果看到`Kibana is now available`，那就是启动完成了。也可以通过netstat查看端口5601是否启动。

通过浏览器访问该地址的5601端口，即可打开登录页。使用内置elastic账户+超管密码登陆即可进行后续操作。

## 安装Fleet Server

Fleet Server是接受Elastic Agent或者各种Beat发送过来的数据并存储到ES的服务。比较蛋疼的是，FleetServer是集成在ElasticAgent这个二进制文件里面的，所以agent体积巨大。

![Fleet Server on-premises deployment model](https://www.elastic.co/guide/en/fleet/8.4/images/fleet-server-on-prem-deployment.png)

MetricBeat等beat工具则比较轻量一些，可以直接传输数据到ES，不过此类工具就无法通过kibana直接进行配置升级等管理了。

这里还是先使用Agent+Fleet的方式安装：

1. 先在kibana的`Management-Fleet-设置`里，设置安装fleet的主机。由于是无状态服务，所以可以有一个或者多个地址。我们这里都装一起，所以Fleet地址就是es这台机器的内网地址。注意这里**只能用HTTPS**；

2. 切到代理策略的tab中，创建一个代理策略，填好名称并同样收集这台设备本身的收集；

3. 创建之后，点“添加集成”，进去搜`FleetServer`，配置服务的Host和Port，可以配置一个最大流量。

4. 登陆ES所在的机器，通过

`/usr/share/elasticsearch/bin/elasticsearch-keystore show xpack.security.http.ssl.keystore.secure_password`

可以看到`http.p12`的密码。

5. 然后切到`/etc/elasticsearch/certs`下面，输入：

`openssl pkcs12 -in http.p12 -out http_cert.crt -clcerts -nokeys`，根据提示输入上面获得的密码，生成crt文件；

6. `openssl pkcs12 -in http.p12 -out http.key -nocerts -nodes`，重复输入密码，生成key文件；
7. 这样我们就凑够了安装Fleet要的所有资料。切到代理的tab页，点击advanced，选择第2步创建的策略，部署模式选择生产，主机选择在第1步中创建的那个。然后选择主机平台，将对应的cli语句copy下来，并修改`<>`里的内容，最后的形式大概如下：

```bash
sudo ./elastic-agent install --url=https://10.20.121.2:8220 \
  --fleet-server-es=https://10.20.121.2:9200 \
  --fleet-server-service-token=AAEAAWVsYXN0aWMvZmxlZXQtc2VydmVyL3Rva2VuLTE2NjU3MzA1NzExMDg6Zmh6RzIyUTFTMnlHMGxwY2gtUkdvdw \
  --fleet-server-policy=4e3a7e30-4b70-11ed-bea5-2fb24f0ee1fa \
  --certificate-authorities=/etc/elasticsearch/certs/http_ca.crt \
  --fleet-server-es-ca=/etc/elasticsearch/certs/http_ca.crt \
  --fleet-server-cert=/etc/elasticsearch/certs/http_cert.crt \
  --fleet-server-cert-key=/etc/elasticsearch/certs/http.key
```

这里的es和fleet用了同一个ca文件，官方建议是为每个fleet-server生成不同的ca以及key/cert，这太麻烦了，所以我们这里共用了同一套。

如果害怕泄露，可以自行生成一套，生成方法是：

```bash
/usr/share/elasticsearch/bin/elasticsearch-certutil cert \
  --name fleet-server \
  --ca-cert /path/to/ca/ca.crt \
  --ca-key /path/to/ca/ca.key \
  --dns your.host.name.here \
  --ip 192.0.2.1 \
  --pem
```

把dns和ip换成fleet server所在的机器名和ip就行。

## 安装Elastic Agent

由于FleetServer和ElasticAgent实际上是同一个二进制文件，所在FleetServer所在的机器就没必要再装agent了。这里另外找一台主机来安装agent.

非k8s环境：

1. 登陆要安装agent的机器，先配置ca证书（适用于centos）：

```bash
yum install ca-certificates
update-ca-trust enable
# 把es生成的ca证书copy到agent所在的设备
mv http_ca.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
```

2. 切到代理策略页面，点击添加代理，选择在Fleet中注册，然后copy下面生成的命令行代码，到要监控的机器上执行；
3. 一切正常的话，主机就会显示在代理页面上；

## 安装Metricbeat

令人比较蛋疼的是，agent虽然好用，但是很多功能都还没集成进去。比如监控ElasticSearch自身，这个功能目前还只有MetricBeat支持，所以在ES这台机器上还要安装一个MetricBeat。

MetricBeat就是完全单独安装了，通过rpm下载或者直接yum安装，然后打开`/etc/metricbeat/`下的配置文件修改如下配置：

```yaml
output.elasticsearch:
  # Array of hosts to connect to.
  hosts: ["https://localhost:9200"]

  # Protocol - either `http` (default) or `https`.
  protocol: "https"

  # Authentication credentials - either API key or username/password.
  #api_key: "id:api_key"
  username: "elastic"
  password: "${ES_PWD}"
  ssl:
    enabled: true
    ca_trusted_fingerprint: "${ES_PRINT}"
```

es的密码最好不要明文写在配置文件里，通过

```bash
metricbeat keystore create
metricbeat keystore add ES_PWD
```

将敏感信息保存在钥匙链里。其中ES_PRINT就是es那个ca证书的指纹，可以通过openssl重新获取。

然后到kibana的堆栈管理（这里翻译有点问题…），安全-用户里面给MetricBeat创建一个用户，角色选`remote_monitoring_agent`。

然后激活metricbeat的es采集功能：

```bash
metricbeat modules enable elasticsearch-xpack
```

配置`modules.d/

## 安装Elastic APM

这里的APM其实指的是Trace系统，通过Fleet直接装就可以。

由于应用还未做好准备，这里先不搞，后续再增补相关步骤。

## Prometheus Metric采集



## 日志采集

## 数据生命周期管理

## 告警配置