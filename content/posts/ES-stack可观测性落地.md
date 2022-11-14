---
title: Elastic Observability系统搭建
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
draft: false
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

es在安装时会自动生成CA证书，在`/etc/elasticsearch/certs`下，客户端所在的机器需要copy证书并信任，才能正常进行HTTPS通信。**注意需要在`xpack.security.http.ssl`下增加一个配置：`verification_mode: certificate`**，这个默认没有写。

ES可以通过`PUT /_cluster/settings`的API直接修改整个集群的配置，不必一台一台去改配置文件，当然kibana上修改也行。只有一小部分需要通过手动修改配置文件指定（如集群的名字等）。es的配置项非常多，不过大部分保持默认即可，需要注意的主要是[这里](https://www.elastic.co/guide/en/elasticsearch/reference/current/important-settings.html).

尤其注意，一旦打开集群模式，即将`network.host`配置打开，es启动时就会进行严格自检，如果有不满足的配置，则无法正常启动。**需要注意的点包括**：

* 修改文件描述符限制；
* 关闭swap；
* 在`sysctl.conf`里面设置`vm.max_map_count=262144`；
* 调整最大线程数限制；
* 根据需求调整jvm、dns设置，以及tcp重传超时设置；
* 确认/tmp文件夹允许执行二进制文件；

在配置完成之后，**需要删除掉配置文件中的`cluster.initial_master_nodes`**，再重新启动。

另外，如果是单机启动，可以加上`discovery.type: single-node`。

可以通过设置

```yaml
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
```

关闭ssl加密通信，**但是最好别这么做**，因为下面的Fleet会强制使用SSL。

重启之后使用curl命令重新测试一下，保证配置文件没改错。

### 集群管理

建议先在单节点上搭建kibana，之后再修改配置成为集群。

1. 修改原来的单点es，主要修改如下配置：

```yaml
cluster.name: your-cluster
node.name: node-1
# 最重要的
network.host: your-LAN-addr
# 本地，以及其他节点的内网地址
discovery.seed_hosts: ["127.0.0.1"]
# master备选
cluster.initial_master_nodes: ["node-1", "node-2", "node-3"]
transport.host: 0.0.0.0
```

然后将`elasticsearch.yml`, `elasticsearch.keystore`和`certs`文件夹copy到其他节点。

2. 先重启第一个节点，让节点自检配置文件，无误后再操作其他节点加入集群；
3. 将copy过来的文件移动到`/etc/elasticsearch`下面，并修改owner为`root:elasticsearch`，这里假设用root操作；
4. certs下的`p12`文件，需要修改权限为660；
5. 新节点的sysctl.conf以及limits.conf也要配置，参考单点时的描述；
6. 新节点需要修改yaml中的`node.name`以及`network.host`配置；并修改`discovery.seed_hosts`加入第一个节点的内网地址；
7. 使用`systemctl start`启动服务；或者使用官网提示的`token` enroll方式加入（仅适用于第一次启动进程）；
8. 注意：**如果需要修改集群配置，直接删除配置的data目录下的所有文件**；
9. 修改kibana以及其他组件的配置，指向整个es集群；
10. 进入kibana，打开堆栈监测，可以看到有3个结点；

整个集群的逻辑就是有个初始master节点作为种子，然后其他结点通过seed_hosts连接这个初始节点，最终组成集群。初始的种子节点如果需要重启，也需要在seed_hosts里面加入其他节点。如果整个集群全部都宕机了，就要重复一遍这个流程了。

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

如果要设置`kibana_system`的密码：

```bash
bin/elasticsearch-reset-password -u kibana_system
```

这里会生成一个随机密码。

### 配置kibana

配置文件在/etc/kibana下，需要配置的一般包括：

```yaml
server.port: 5601
server.host: "0.0.0.0"
server.name: "your-system-name"
elasticsearch.hosts: []
# 用户名和密码或者token设置一个就可以
elasticsearch.username: "kibana_system"
# 刚才生成的密码
elasticsearch.password: "xxxx"
# 或：刚才复制的token
# elasticsearch.serviceAccountToken: ""
# 语言改成中文，不过中文翻译实际上有点问题……可以的话用英文更好
i18n.locale: "zh-CN"
# 外网访问地址，如果是有域名则配置域名，或者一般配置反代的地址
server.publicBaseUrl: "http://<out-ip>:5601"
```

改好之后通过`systemctl start kibana`启动服务，通过`journalctl -u kibana`查看日志，如果看到`Kibana is now available`，那就是启动完成了。也可以通过netstat查看端口5601是否启动。

通过浏览器访问该地址的5601端口，即可打开登录页。使用内置elastic账户+超管密码登陆即可进行后续操作。

## 安装Fleet Server

Fleet Server是接受Elastic Agent或者各种Beat发送过来的数据并存储到ES的服务。比较蛋疼的是，FleetServer是集成在ElasticAgent这个二进制文件里面的，所以agent体积巨大。

![Fleet Server on-premises deployment model](https://www.elastic.co/guide/en/fleet/8.4/images/fleet-server-on-prem-deployment.png)

MetricBeats等beats工具则比较轻量一些，可以直接传输数据到ES，不过此类工具就无法通过kibana直接进行配置升级等管理了。

这里还是先使用Agent+Fleet的方式安装，方便后续升级管理：

1. 先在kibana的`Management-Fleet-设置`里，设置安装fleet的主机。由于是无状态服务，所以可以有一个或者多个地址（多个的话使用负载均衡地址）。我们这里都装一起，所以Fleet地址就是es这台机器的内网地址。注意这里**只能用HTTPS**；

2. 切到代理策略的tab中，创建一个代理策略，填好名称并同样收集这台设备本身的收集，**注意一台主机只能分配一个代理策略，虽然感觉不太合理，但是勉强也够用**；

3. 创建之后，点“添加集成”，进去搜`FleetServer`，配置服务的Host和Port，可以配置一个最大流量。注意**命名空间**那里填的是环境，一般是`dev`,`test`之类的；高级设置的地址里填`0.0.0.0`，端口可以用默认的；

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
  --fleet-server-service-token=<your token> \
  --fleet-server-policy=4e3a7e30-4b70-11ed-bea5-2fb24f0ee1fa \
  --certificate-authorities=/etc/elasticsearch/certs/http_ca.crt \
  --fleet-server-es-ca=/etc/elasticsearch/certs/http_ca.crt \
  --fleet-server-cert=/etc/elasticsearch/certs/http_cert.crt \
  --fleet-server-cert-key=/etc/elasticsearch/certs/http.key
```

如果在FleetServer前面挂了一个负载均衡的反代，那`--url`后面就要改成反向代理的地址了，实际上`es`的地址也可以改成反代的地址。

这里的es和fleet用了同一个ca文件，官方建议是为每个fleet-server生成不同的ca以及key/cert，这太麻烦了，所以我们这里共用了同一套。

如果害怕泄露ca文件导致的安全问题，可以为fleet-server单独生成一套，生成方法是：

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

如果需要卸载Fleet(或者说Elastic Agent)，运行`/opt/Elastic/Agent/elastic-agent uninstall`即可。

## 安装Elastic Agent

由于FleetServer和ElasticAgent实际上是同一个二进制文件，所在FleetServer所在的机器就没必要再装agent了。这里另外找一台主机来安装agent.

**非k8s环境：**

1. 登陆要安装agent的机器，先配置ca证书（适用于centos）：

```bash
yum install -y ca-certificates
update-ca-trust enable
# 把es生成的ca证书copy到agent所在的设备
mv http_ca.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust extract
```

2. 切到代理策略页面，点击添加代理，选择在Fleet中注册，然后copy下面生成的命令行代码，到要监控的机器上执行；
3. 如果Fleet有多个Server，且没有使用反向代理，这里会默认使用第一个的地址，可以手动修改一下再执行；
4. 一切正常的话，主机就会显示在代理页面上；

**k8s环境：**

1. 实际上仍然是在宿主机上安装，不过是通过DaemonSet与k8s整合；
2. 具体流程请参考[这里](https://www.elastic.co/guide/en/fleet/current/running-on-kubernetes-managed-by-fleet.html)；
3. 仍然推荐先在宿主机上信任证书；

## 安装Metricbeat(ECS/可选)

### 基础配置

对ES的简单监控可以用es自带的monitor，将`xpack.monitoring.collection.enabled`打开即可，可以在kibana上面操作完成。

Elastic Agent虽然设计的是ALL-IN-ONE，但是很多功能都还没集成进去(v8.4)，比如监控ElasticSearch自身。所以如果不用ES自带的监控，就需要安装MetricBeat来完成该功能。

> MetricBeat也无法监控FleetServer和ElasticAgent，所以如果你在一台设备上同时安装了FleetServer和ElasticSearch本身，那么要安装三个Agent。
>
> 不过估计到v9的时候ElasticAgent就会集成所有常见的功能了，现在处于过渡时期。

MetricBeat就是完全单独安装了，通过rpm下载或者直接yum安装。

打开`/etc/metricbeat/`下的配置文件修改如下配置：

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
metricbeat keystore add ES_PWD --force
metricbeat keystore add ES_PRINT
```

将敏感信息保存在钥匙链里。

其中ES_PRINT就是es那个ca证书的指纹，通过`openssl x509 -fingerprint -sha256 -in /etc/elasticsearch/certs/http_ca.crt`可以看到，**特别注意的是需要去掉其中的冒号`:`**，将其转为一个16进制字符串。

> 这里建议将monitor的配置也打开，监控自身：monitor.enabled=true

### 采集ES信息

然后到kibana的堆栈管理（这里翻译有点问题…），修改内置账户`remote_monitoring_user`的密码，记下来。

然后激活metricbeat的es采集功能：

```bash
metricbeat modules enable elasticsearch-xpack
```

配置`modules.d/elasticsearch-xpack.yml`，修改如下内容：

```yaml
- module: elasticsearch
  xpack.enabled: true
  period: 10s
  hosts: ["https://localhost:9200"]
  # 上面设置的账户
  username: "internal_metric"
  #上面设置的密码
  password: "xxxx"
```

另外就是把ca证书标记为系统信任，这样就不需要再配置ssl了。

由于agent那边已经采集了system，所以这边最好用`metricbeat modules disable system`关掉避免重复采集。

### 启动服务

然后启动MetricBeat：

```bash
# 该步骤较慢，请耐心等待
metricbeat setup
systemctl enable metricbeat
systemctl start metricbeat
```

可以通过`journalctl -u metricbeat`查看日志，如果没有ERROR应该就是OK了（日志很长，可以用左右箭头移动看具体错误）。

## 安装Metricbeat(k8s)
### 基础配置
下载metricbeat配置文件，使用命令
```bash
curl -L -O https://raw.githubusercontent.com/elastic/beats/8.4/deploy/kubernetes/metricbeat-kubernetes.yaml
```
> 配置文件下载之后，首先将文件中所有的namespace修改为metricbeat

找到Metricbeat配置ES信息的位置，将`ELASTICSEARCH_HOST`和`ELASTICSEARCH_PORT`修改为对应ElasticSearch的IP和端口，将`ELASTICSEARCH_USERNAME`和`ELASTICSEARCH_PASSWORD`修改为对应的ElasticSearch用户名和密码
```yml
        env:
        - name: ELASTICSEARCH_HOST
          value: 10.20.121.2
        - name: ELASTICSEARCH_PORT
          value: "9200"
        - name: ELASTICSEARCH_USERNAME
          value: elastic
        - name: ELASTICSEARCH_PASSWORD
          value: a-WxDYOh65KAIPSx1O6s
```
另外，metricbeat默认的内存配置太小，需要改大，这里将`limits`调整为500MB
```yml
        resources:
          limits:
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 100Mi
```
如果es没有启用ssl，那么到这里基础配置就结束了，如果启用了ssl，还需要配置ssl信息
找到配置文件中的`output.elasticsearch`部分，将其修改为
```yml
output.elasticsearch:
  hosts: ['${ELASTICSEARCH_HOST:elasticsearch}:${ELASTICSEARCH_PORT:9200}']
  username: ${ELASTICSEARCH_USERNAME}
  password: ${ELASTICSEARCH_PASSWORD}
  protocol: https
  ssl:
      enabled: true
      ca_trusted_fingerprint: "${ES_PRINT}"
```
其中ES_PRINT就是es那个ca证书的指纹，使用同ECS中的metricbeat配置，参考上文.

### 服务监控配置
首先确保各k8s中的服务都已引入prometheus并以通过http接口暴露metric。
找到配置文件中的`metricbeat.autodiscover`配置项，将其修改为：

```yml
metricbeat.autodiscover:
  providers:
    - type: kubernetes
      include_labels: ["app"]
      templates:
        - condition:
            contains:
              kubernetes.labels.app: "sim-iotgateway"
          config:
            - module: prometheus
              metricsets: ["collector"]
              hosts: "${data.host}:${data.port}"
              metrics_path: /metrics/prometheus
              period: 30s      
```
上面使用的是metricbeat的自动探测功能，自动监控了iot的iotgateway服务，其中的`metrics_path`是服务暴露的metric接口路径，period是metric采集周期。下面这一段代表的是要采集那个服务的metric。
```yml
templates:
        - condition:
            contains:
              kubernetes.labels.app: "sim-iotgateway"
```
这里使用了metricbeat的标签过滤功能，要配置哪个服务，就过滤哪个服务的标签即可。

如果要新增hermes服务的监控，只需新增对应的配置
```yml
metricbeat.autodiscover:
  providers:
    - type: kubernetes
      include_labels: ["app"]
      templates:
        - condition:
            contains:
              kubernetes.labels.app: "sim-iothermes"
          config:
            - module: prometheus
              metricsets: ["collector"]
              hosts: "${data.host}:${data.port}"
              metrics_path: /metrics/prometheus
              period: 30s
    - type: kubernetes
      include_labels: ["app"]
      templates:
        - condition:
            contains:
              kubernetes.labels.app: "sim-iotgateway"
          config:
            - module: prometheus
              metricsets: ["collector"]
              hosts: "${data.host}:${data.port}"
              metrics_path: /metrics/prometheus
              period: 30s    
```
每个服务的标签labels，可以在对应服务k8s的yaml中找到，例如：
```yml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    cattle.io/timestamp: "2022-10-18T09:48:42Z"
    kubernetes.io/psp: ack.privileged
  creationTimestamp: "2022-10-21T09:31:34Z"
  generateName: deploy-sim-iothermes-5bc86c5bb7-
  labels:
    app: sim-iothermes
    pod-template-hash: 5bc86c5bb7
```

### 部署
修改完`metricbeat-kubernetes.yaml`之后，在k8s机器上执行下述命令即可
> 注意，这里采用的是DaemonSet模式
```bash
kubectl create -f metricbeat-kubernetes.yaml
```
部署完成后，也可在configmap中的metricbeat.yml中进行监控服务的增删.

## 安装Filebeat

同样，如果不想使用ElasticAgent的custom logs，out-of-box地收集elasticsearch的日志还是要装filebeat，流程也很类似：

```bash
filebeat keystore create
filebeat keystore add ES_PWD
filebeat keystore add ES_PRINT
```

然后修改`filebeat.yml`，将`output.elasticsearch`设置为类似MetricBeat的配置。inputs那边不用管，因为我们使用modules配置。

> 另外这里可以将moniter的enable打开，监控自身的metric

然后`filebeat modules enable elasticsearch`，修改`elasticsearch.yml`，设置`enabled=true`。

最后：

```bash
filebeat setup
systemctl enable filebeat
systemctl start filebeat
```

使用journalctl查看日志即可。

另外kibana所在的机器还要打开kibana的日志收集，配置方法类似。

在ES所在机器安装了MetricBeat和Filebeat之后，就可以在kibana的**堆栈监测**里面看到es相关信息，差不多就是下图的样子：

![image-20221017104832361](https://s2.loli.net/2022/10/17/crdIyuoa97LKDjJ.png)

如果仅仅使用es自带的monitor，则不会有下面的beats部分，**同时也不会有log的监控**。

## 数据生命周期管理(ILM)

在**Stack Management**-**索引生命周期管理**里管理index的生命周期策略，这里默认就会有filebeat和metricbeat自动创建index的生命周期，可以根据需求进行修改。冷阶段不支持搜索，除非有企业许可证。

Elastic Agent采集的Metric，则是默认使用`metrics`策略管理，即所有数据都在hot阶段，这里肯定需要自定义存储策略。

进入**索引管理**-**数据流**，搜索prometheus可以看到`metrics-prometheus.collector-test`，点击可以看到索引模板是`metrics-prometheus.collector`。到索引模板里clone这个模板，将优先级改到250（或者直接改这个索引模板的配置也可以），在**索引配置**页面加上：

```json
{
  "lifecycle": {
    "name": "metricbeat"
  }
}
```

点击保存。回到数据流tab，再次点击刚才的数据流，就会发现索引模板已经变成新的了，而且生命周期策略也改成`metricbeat`了。

在`索引模板`里面搜索`agent`，可以看到所有elastic agent自动创建的模板，可以看到`metrcis-`开头的默认的ILM都是`metrics`，建议根据自己的使用情况全部改成自定义的ILM。感觉这个设计不是很合理，期望后续的版本使用非托管策略方便修改。

## Prometheus Metrics采集(Fleet)

Elastic Agent已经集成了Prometheus Metric采集功能（还是beta），当然我们也可以使用MetricBeat来完成。

生产环境推荐使用filebeat+metricbeat的方式采集日志和系统信息，等到Elastic Agent稳定之后再替换掉。而且beat目前采集信息可以送到kafka，避免把es压垮。这里为了方便还是直接用Fleet，毕竟我们的服务产生的数据量没那么大。

进入Fleet，选择代理策略，选择**添加集成**，搜索`Prometheus Metrics`，出来的是MetricBeat版本，点进去之后会提示你有agent版本，切换过去。我这边用的时候最新版是`0.13.0`，点击`添加Prometheus Metrics`按钮即可一键部署。

注意点击**修改默认值**，去修改服务的地址。

在discover那边，将索引切换到`metrics-*`，搜索`prometheus*:*`应该可以看到有数据采集过来。不过MetricBeat采集的数据使用的索引是`metricbeat-*`,两者默认使用不同的ILM，上文已经通过手动修改将二者都改成`metricbeat`的ILM了.

## Uptime监控

可以使用heartbeat或者新的uptime app(在Observability-Uptime-Monitor右上角有个`监测管理`的入口)来监控接口或者主机的可用性，支持进行模拟浏览器/HTTP/TCP/ICMP的探测。

对于自建的服务，一般情况下，设置metrics就可以判断服务的存活性了。云主机的存活性一般不需要关心，边缘端或者自建机房可以考虑加一个ping探测。

不过，Uptime还可以是对第三方服务的，甚至可以用浏览器行为来进行前端自动化探测，如果**服务依赖第三方接口**，可以考虑加上相关探测。自建服务如果需要供外网访问，也可以将heartbeat安装在外网机器，从而进行端到端的探测。

由于暂时没有啥必须监控的东西，这里我们就先不进行配置了。

## 应用日志采集

前面配置filebeat采集日志的流程已经写了，当然也可以用来收集自定义日志，只要配置yaml配置一下路径就行。

这里使用Elastic Agent来进行采集，其实流程差不多：简单来说，在Fleet中集成`Custom Logs`，配置上日志路径就OK了。

不过一般我们并不采集所有应用日志（因为大部分都是辣鸡信息），正确的做法是把重要信息先结构化成json日志，然后再采集那些结构化日志。ES规定了一份详细的日志规范，简称ECS，文档请参考[这里](https://www.elastic.co/guide/en/ecs/current/ecs-reference.html)。保证所有的应用使用同样的字段才能更好的过滤信息，这其实是一种管理策略。

这里演示一下另外一个常用的场景，采集ERROR日志用来告警，这个一般并不需要结构化日志，直接提取日志中的ERROR行即可。

### 数据预处理

在数据传入es之前可以使用管道对数据进行预处理，在`Stack Management`-`采集`-`采集管道`里面建立处理流程即可。注意映射的字段尽量遵守上面的ECS规范。

对于plain text日志，最常用的processor是`dissect`（中文翻译是分解），`grok`和`script`三种，用来提取字段，其中grok用的其实就是正则匹配。

假设我们这里有golang服务日志格式如下：

> 2022-08-18T15:54:52.866+0800    WARN    internal/kafka.go:37    [kafka]poll errors:[{ 0 client closed}]

这里有文件路径，但这个字段只有debug模式下才打开，正常的日志格式则是这样的：

> 2022-08-18T15:54:52.866+0800    WARN    [kafka]poll errors:[{ 0 client closed}]

由于字段不固定，所以这个需求无法使用`dissect`完成，只能选择`grok`或者脚本。

这里用grok，参考[官方文档](https://www.elastic.co/guide/en/elasticsearch/reference/current/grok.html)，可以写下如下匹配规则：

> %{TIMESTAMP_ISO8601:@timestamp}%{SPACE}%{LOGLEVEL:log.level}%{SPACE}%{GREEDYDATA:message}

先到kibana**开发工具**下面的`Grok Debugger`里面去测试，可以看到模拟结果为：

```json
{
  "@timestamp": "2022-08-18T15:54:52.866+0800",
  "message": "internal/kafka.go:37    [kafka]poll errors:[{ 0 client closed}]",
  "log": {
    "level": "WARN"
  }
}
```

如果我们不想要中间的`internal/kafka.go:37`这部分，就稍微麻烦一些，定义

> CALLER (\s+([/\w_%!$@:.,+~-]+|\\.)*:\d+)?

然后将表达式改为：

> %{TIMESTAMP_ISO8601:@timestamp}%{SPACE}%{LOGLEVEL:log.level}%{CALLER}%{SPACE}%{GREEDYDATA:message}

这样就可以强行把中间的caller部分过滤掉。

需要注意的是，在kibana界面上添加管道时，**需要对`\`进行转义**，即改为`(\\s+([/\\w_%!$@:.,+~-]+|\\.)*:\\d+)?`。

添加完成之后可以点击**添加文档**，在pipeline里再测试一次。同时也可以在后面添加别的pipeline进一步处理，比如添加新字段等。

部分预处理需要使用[painless脚本](https://www.elastic.co/guide/en/elasticsearch/painless/current/painless-ingest-processor-context.html)，比如某些服务没有区分error日志与普通日志，那么需要drop掉warn等级以下的日志，可以用`ctx.log.level != 'WARN' && ctx.log.level != 'ERROR'`。

一般同一种语言使用相同的日志格式，这里假设添加管道的名字为`golang-common-log-parser`，并创建一个`common-logs-policy`的策略，对所有应用日志生命周期进行统一管理。

### 配置索引模板

我们需要将上面的grok转换后的格式关联一个索引模板。

先创建一个组件模板以供复用，到`Stack Management`-`索引管理`下面，点击**组件模板**tab页下**创建**相关按钮，填入名称（如custom-logs@mapping），在**映射**页面配置字段映射：

![image-20221102111708534](https://s2.loli.net/2022/11/02/iOIGgqcJyrnQf1P.png)

对应的json配置如下：

```json
{
  "@timestamp": "Date",
  "log": {
      "level": "Keyword"
  },
  "message": {"Other: match_only_text"}
}
```

然后点击**索引模板**tab页上的按钮，创建一个索引模板，假设名为`golang-logs-template`，在`index patterns`下面填入**日志索引的格式，如`logs_golang*`**，打开`Create data stream`，并将**优先级设置为>100的数值**。点击下一步，添加刚才创建的组件模板，添加，在`index settings`中关联ILM：

```json
{
    "index":{
        "lifecycle":{
            "name": "common-logs-policy"
        }
    }
}
```

然后一路next，创建完毕。

由于默认的`logs-*`的匹配优先级是100，我们创建了优先级更高的模板，就自动将形如`logs-golang*`的索引自动关联到新的索引模板和生命周期策略上了。

另外提一下，golang的panic日志一般不需要采集，直接用`File Integrity Monitoring Integration`这个集成进行文件监测即可。

### 配置采集器(Fleet)

![image-20221026180330634](https://s2.loli.net/2022/10/26/WRYNswyo1d3qrJV.png)

在`Custom Logs`的添加界面上，命名空间配置当前环境(如`dev`)，点击高级配置，dataset填入服务的名字，如`golang_video`，这样最后index的名字就是`logs-golang_video-dev`，由于这里已经指定中划线作为分隔符，所以dataset中不能出现`-`. 建议这里将同一个格式的日志放在一个配置里（不同命名空间的需要分开），方便修改，可以从log.path里分辨出日志具体属于哪个服务。

通过名称匹配，这个索引会自动关联上文创建的索引模板。pipeline则需要手动关联，在`Custom configurations`下面，填入如下yaml：

```yaml
pipeline: golang-common-log-parser
```

日志路径可以添加多个，可以使用通配符。

### 确认配置

一切正常的话，在Observablity里面正常应该可以看到刚添加的应用日志了，也可以在`Discover`里面自己过滤查询。

可以用`event.dataset`搜索上面添加的`golang_sip_server`，看到对应的日志。

如果没有日志，一般在Fleet的代理日志里可以看到相关信息。或者去所在机器的`/opt/Elastic/Agent`目录下，查看采集侧的`njson`日志。ES这边的日志需要使用filebeat监控才能在kibana中看到，可以去

## KQL简单学习

ES的查询语法是复杂的JSON，直接在界面上不方便使用，所以kibana实际上使用了一种名为KQL的方言（DSL）。其使用较为简单，这里记录一下要点：

1. 简单的term匹配，使用`k: v`的形式，多个v可以用空格隔开，表示**或**关系。如果值中包含空格，使用双引号；
2. 允许使用and, or和not逻辑操作，允许使用括号；注意not是放在k前面的，而不是v前面；
3. 数组匹配多个值，使用and，如`tags:(success and info and security)`;
4. 范围查询，支持>, <, = 各种组合；
5. 日期查询一般用右侧的time filter，不过也可以手动写 `@timestamp < "2022-10-10"`之类的，也支持类似influxdb的算术表达式；
6. 允许使用`*`做模糊匹配，k或者v中都可以；
7.  list of object的匹配，匹配object中的字段，使用大括号。例如`items:{name: banana}`这种；
8. 如果是多级嵌套，如`k1:[{k2: [{"k3": "v"}]]`，搜索的时候需要写全路径，即`k1.k2:{k3: v}`这种搜索；

## 安装Elastic APM(TODO)

这里的APM其实指的是Trace系统，通过Fleet直接绑定集成就可以。

由于应用还未做好准备，这里先不搞，后续再增补相关步骤。这里的关键在应用改造，集成的难度其实不大。

## 周期性任务

很多指标需要持续计算，比如日活，统计周期内的错误占比等。

在`StackManagement`-`汇总/打包作业`里，可以创建定时任务，具体使用请查看[官方文档](https://www.elastic.co/guide/en/elasticsearch/reference/current/rollup-put-job.html).

## 告警配置

下面开始配置告警，告警有很多入口，请根据需要选择：

1. 在可观测性(Observability)里，这里可以设置简单的阈值告警；
2. 在Security-告警里，这里可以使用复杂的表达式从ES中进行各种数据查询并创建告警;
3. 在Stack Management-告警和洞见-Watcher里，这里可以直接用json语句创建告警，这是最灵活，同时也是最复杂的方法；
4. （推荐）还是在告警与洞见这里，在规则和连接器里，这里可以设置所有场景的告警，也包括一般的es查询；

### 连接器

告警的发布对象被称为“连接器”，免费提供的只有kibana日志和写入es index，有三个解决方案：

1. 可以自己写一个简单的工具监控es/kibana日志并调用钉钉发送告警；
2. 使用[ElasticAlert2](https://elastalert2.readthedocs.io/en/latest/elastalert.html)项目；
3. 升级到白金许可证（或者使用[这个项目](https://github.com/wolfbolin/crack-elasticsearch-by-docker)）；

这里假设你已经获得了白金许可证，下面使用webhook报警即可。

首先在钉钉群里配置一个机器人，点击群设置-**智能群助手**，添加一个webhook机器人，建议打开IP白名单，或者告警关键词。

钉钉创建一个含有access_token的URL，copy下来，在webhook连接器POSt后面paste这个地址，然后添加header`Content-Type: application/json`，用json格式发送。

点击保存，在测试页面进行报警测试，消息的格式请参考[这里](https://open.dingtalk.com/document/robots/custom-robot-access#title-72m-8ag-pqw)，可以用

```json
{
    "msgtype": "text",
    "text":{
        "content": "Hello World"
    }
}
```

做个简单测试。

### 告警规则

在安全里可以安装Elastic预构建的几百个规则，不过不是很建议全部导入，因为大部分都没啥用。可以考虑激活k8s，linux之内tag的规则，如果使用云厂商自带的监控，则一般不必再使用这里的告警功能，相当于重复监测了，而且**有性能损耗**。

#### Observability使用示例

如果只是简单的创建一个error日志告警，可以在Observability点击创建规则，选择日志阈值，然后创建一个如下的规则：

![image-20221020141946295](https://s2.loli.net/2022/10/20/chDWbTyCmFlVs2f.png)

由于我们在上面的数据预处理里面已经将log.level映射出来，所以这里使用这个字段判断一下就行。连接器选择刚才创建的webhook，在Fired和Recovered两种条件下创建两个不同的告警提示即可。

![image-20221020142216332](https://s2.loli.net/2022/10/20/lIORdb4Dt6GwngU.png)

右侧可以看到这里可以使用的变量。可以注意到这里并**没有字段可以拿到日志的详情**，这是因为这里只能做聚合查询，肯定是拿不到具体日志的详情的，不过可以通过group by source.ip之类的方式获取到具体的主机。如果需要直接提示详细的错误，需要用其他方案；

#### 告警与洞见使用示例（推荐）

点击**创建规则**，选择**Elasticsearch查询**，选择KQL查询，创建一个视图`logs-golang*`作为索引，这样就自动匹配所有golang服务。

如果不想这么粗放的创建告警，也可以用`logs-golang_sip_server*`，作为匹配，这样就匹配到单个服务的所有日志。所以index的名字很重要，不要随便取。

![image-20221021090656229](https://s2.loli.net/2022/10/21/EqnO2xCD1f6Hb8R.png)

查询条件仍然是日志等级为ERROR（这里是区分大小写的，可以在预处理里统一转换成大写），这里就是过去5分钟出现任意错误日志则触发。这里在body里面可以拿到`{{context.hits}}`，我们可以通过[mustache](http://mustache.github.io/mustache.5.html)这个模板语言对其内容进行解析。

告警模板：

```
{
    "msgtype": "markdown",
    "markdown":{
        "title": "Error log found!",
        "text":"""在过去3分钟内发现{{context.value}}条错误日志，摘录如下： 
 {{#context.hits}} 
 **{{_source.log.file.path}}@{{_source.host.hostname}}:** 
 {{_source.@timestamp}}  {{_source.message}} 
 {{/context.hits}} 
 点击[此链接]({{context.link}})查看详情。"""
    }
}
```

这里三个双引号是kibana特有的语法(与json实际上不兼容)，方便写多行字符串。

恢复模板：

```json
{
    "msgtype": "text",
    "text":{
        "content":"logs-golang*已无新增错误日志"
    }
}
```

效果如图：

![image-20221021112827617](https://s2.loli.net/2022/10/21/iFZBmhLjnrRbNAG.png)

#### 安全告警使用示例

这里其实不太建议使用，非安全问题用这里的规则不太符合ES本身的设计，具体使用方法请自己摸索。

#### watcher使用示例

watcher属于高级用法，需要自己写全量的JSON来拼凑出表达式，而且也**不支持使用已经配置的连接器**，有兴趣可以看[这里](https://blog.csdn.net/qq_42259469/article/details/124720184)，官方github给出了大量[examples](https://github.com/elastic/examples/tree/master/Alerting)，以供参考。这里不太建议使用，因为用起来很麻烦，也不好调试。

### ElasticStack自身的告警

在告警与洞见里，默认就有一些检测ES本身状态的规则，可以修改。默认只是将告警输出到kibana日志。

查看日志级别，如果是Warning以上的，可以加一个钉钉通知：

```json
{
    "msgtype": "markdown",
    "markdown":{
        "title": "ES Cluster Alert",
        "text":"{{context.internalShortMessage}}"
    }
}
```

### 基础设施告警

点击创建告警，在`Metrics`中点击库存(这里翻译也不对……)，这里可以对一般指标（cpu、内存等创建告警）。通用告警模板：

```json
{
    "msgtype": "markdown",
    "markdown":{
        "title": "Host CPU Alert",
        "text":"{{context.reason}} \n For detail click [here]({{context.viewInAppUrl}})"
    }
}
```

其他的指标都在`custom metric`选项里，如磁盘空间使用，可以用`system.filesystem.used.pct`. 建议根据自己的需求阅读官方文档中[system](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-module-system.html)和[linux](https://www.elastic.co/guide/en/beats/metricbeat/current/metricbeat-module-linux.html)这两个采集模块的相关字段解释。

## 看板配置

在`kibana`的`Analytics`部分，可以创建各种看板。

Dashboard里面内置了一部分仪表盘，也可以自己使用KQL筛选数据后自行创建，一般内部监控用这个创建可视化就够了。

Canvas部分则可以通过灵活地拖曳完成各种图表的数据、样式配置，可以非常方便地作出各种炫酷的大屏。

由于这部分内容比较符合使用者的直觉，且更偏向于前端的工作，这里就不写详细的配置步骤了。有需求可以阅读[kibana的文档](https://www.elastic.co/guide/en/kibana/current/create-a-dashboard-of-panels-with-web-server-data.html)来学习。

## 附录：中间件采集

大部分中间件都集成在fleet里了，如果不能满足需求，可以点开custom这一栏。已经有官方集成的这里就不写了，包括MySQL、Redis、kafka、rabbitMQ和Nginx。

### emqx

官方支持`statsd`的[插件](https://github.com/emqx/emqx-prometheus)，配合metricbeat的[Statsd module](https://www.elastic.co/guide/en/beats/metricbeat/8.4/metricbeat-module-statsd.html)，即可采集到数据。

注意ElasticAgent尚不支持该类型数据采集。

### influxdb cluster

支持metrics接口，可以直接用。不过能采集到的数据其实都是默认的golang exporter里面的。

通过`debug/vars`接口可以拿到influxdb本身的监控数据，不过这个不是prometheus格式的，需要自己转换。

可以通过开源的[influxdb exporter](https://github.com/prometheus/influxdb_exporter)或者直接用[telegraf](https://github.com/influxdata/telegraf)作为exporter，后者在output里面启动一个prometheus client即可.

telegraf其实可以代替MetricBeat直接将数据发到es，不过和kibana那套体系配合的不是很好，需要自己管理相关index.

### seaweedFS

参考[这里](https://github.com/seaweedfs/seaweedfs/wiki/System-Metrics)，需要启动服务时额外配置metrics端口。

官方给了grafana的json配置，kibana这边就需要自己配置了。

### 阿里云商用中间件

可以参考[`aliyun-exporter`](https://github.com/aylei/aliyun-exporter)这个repo，虽然已经archive，不过思路没变。
