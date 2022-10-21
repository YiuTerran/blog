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

另外就是es节点默认生成如下roles：

- `master`
- `data`
- `data_content`
- `data_hot`
- `data_warm`
- `data_cold`
- `data_frozen`
- `ingest`
- `ml`
- `remote_cluster_client`
- `transform`

如果手动管理集群的话，一般是要将某些节点改成全职的某个角色以均衡负载。

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

3. 创建之后，点“添加集成”，进去搜`FleetServer`，配置服务的Host和Port，可以配置一个最大流量。注意**命名空间**那里填的是环境，一般是`dev`,`test`之类的；

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

### 基础配置

令人比较蛋疼的是，agent虽然好用，但是很多功能都还没集成进去(v8.4)。比如监控ElasticSearch自身，这个功能目前还只能使用beats，所以在ES这台机器上还要安装一个MetricBeat。

> 更蛋疼的是，目前MetricBeat无法监控FleetServer和ElasticAgent，所以如果你在一台设备上同时安装了FleetServer和ElasticSearch本身，那么要安装三个Agent。
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
metricbeat keystore add ES_PWD
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

## 安装Filebeat

同样，目前收集elasticsearch的日志还是要装filebeat，流程也很类似：

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

这两步结束之后，可以在kibana的**堆栈监测**里面看到es相关信息，差不多就是下图的样子：

![image-20221017104832361](https://s2.loli.net/2022/10/17/crdIyuoa97LKDjJ.png)

## Prometheus Metric采集

Elastic Agent已经集成了Prometheus Metric采集功能（还是beta），当然我们也可以使用MetricBeat来完成，这里测试环境就优先使用agent了。

生产环境推荐使用filebeat+metricbeat的方式采集日志和系统信息，等到Elastic Agent稳定之后再替换掉。而且beat目前采集信息可以送到kafka，避免把es压垮。

进入Fleet，选择代理策略，选择**添加集成**，搜索`Prometheus Metrics`，出来的是MetricBeat版本，点进去之后会提示你有agent版本，切换过去。我这边用的时候最新版是`0.13.0`，点击`添加Prometheus Metrics`按钮即可一键部署。

注意点击**修改默认值**，去修改服务的地址。

在discover那边，将索引切换到`metrics-*`，搜索`prometheus*:*`应该可以看到有数据采集过来。MetricBeat采集的数据使用的索引是`metricbeat-*`,两者使用不同ILM。

### 数据生命周期管理(ILM)

Elastic Agent采集的Metric，默认使用`Metrics`策略管理，即所有数据都在hot阶段，这里肯定需要自定义存储策略。进入**索引管理**-**数据流**，搜索prometheus可以看到`metrics-prometheus.collector-test`，点击可以看到索引模板是`metrics-prometheus.collector`。

到索引模板里clone这个模板，将优先级改到250，在索引配置页面加上：

```json
{
  "lifecycle": {
    "name": "metricbeat"
  }
}
```

创建索引模板。回到数据流tab，再次点击刚才的数据流，就会发现索引模板已经变成新的了，而且生命周期策略也改成metricbeat了。

在**StackManagement**-**索引生命周期管理**里配置数据的生命周期，这里默认就会有filebeat和metricbeat自动创建index的生命周期，可以根据需求进行修改。冷阶段不支持搜索，除非有企业许可证，所以建议稳阶段结束之后直接删除。

## Uptime监控

可以使用heartbeat或者新的uptime app来监控接口或者主机的可用性，支持浏览器/HTTP/TCP/ICMP探测。

对于自建的服务，一般情况下，设置metrics就可以判断服务的存活性了。云主机的存活性一般不需要关心，边缘端或者自建机房可以考虑加一个ping探测。

不过，这里的Uptime还可以是对第三方服务的，甚至可以用浏览器行为来进行前端自动化探测，如果服务依赖第三方接口，可以考虑加上。

此外，API的端到端测试可以使用Uptime来检测，不过通过trace/metrics也可以完成。

由于暂时没有啥必须监控的东西，这里我们就先不进行配置了。

## 应用日志采集

前面配置filebeat采集日志的流程已经写了，当然也可以用来收集自定义日志，只要配置yaml配置一下路径就行。

这里使用Elastic Agent来进行采集：简单来说，在Fleet中集成`Custom Logs`，配置上日志路径就OK了。

不过一般我们并不采集所有应用日志（因为大部分都是辣鸡信息），正确的做法是把重要信息先结构化成json日志，然后再采集那些结构化日志。

具体的日志规范请参考[这里](https://www.elastic.co/guide/en/ecs/current/ecs-reference.html)，保证所有的应用使用同样的字段才能更好的过滤信息。

这里演示一下另外一个常用的场景，采集ERROR日志用来告警，这个一般并不需要结构化日志，直接用匹配（或正则匹配）日志中的ERROR行即可。

### 数据预处理

在数据传入es之前可以使用管道对数据进行预处理，在`Stack Management`-`采集`-`采集管道`里面建立处理流程即可。

对于plain text日志，最常用的processor是`dissect`（中文翻译是分解），`grok`和`script`三种，用来提取字段。其中grok用的其实是正则匹配，而不是一般理解的那种。

假设我们这里有golang服务日志格式如下：

> 2022-08-18T15:54:52.866+0800    WARN    internal/kafka.go:37    [kafka]poll errors:[{ 0 client closed}]

这里有文件路径，只有debug模式下才打开。正常的日志格式是这样的：

> 2022-08-18T15:54:52.866+0800    WARN    [kafka]poll errors:[{ 0 client closed}]

这个需求无法使用`dissect`完成，只能选择`grok`或者脚本。这里用grok，写下如下匹配规则：

> %{TIMESTAMP_ISO8601:@timestamp}%{SPACE}%{LOGLEVEL:log.level}%{SPACE}%{GREEDYDATA:message}

到开发工具下面的`Grok Debugger`里面去测试，可以看到模拟结果为：

```json
{
  "@timestamp": "2022-08-18T15:54:52.866+0800",
  "message": "internal/kafka.go:37    [kafka]poll errors:[{ 0 client closed}]",
  "log": {
    "level": "WARN"
  }
}
```

当然如果我们不想要中间的`internal/kafka.go:37`这部分，就稍微麻烦一些，定义

> CALLER (\s+([/\w_%!$@:.,+~-]+|\\.)*:\d+)?

然后将表达式改为：

> %{TIMESTAMP_ISO8601:@timestamp}%{SPACE}%{LOGLEVEL:log.level}%{CALLER}%{SPACE}%{GREEDYDATA:message}

这样就可以强行把中间的caller部分过滤掉。

在界面上添加管道时，需要对`\`进行转义，即改为`(\\s+([/\\w_%!$@:.,+~-]+|\\.)*:\\d+)?`，添加完成之后可以点击添加文档，然后在pipeline里再测试一次。

假设添加管道的名字为`golang-common-logs-parser`，并创建一个`common-logs-policy`的策略，对所有应用日志生命周期进行统一管理。

### 配置索引模板

我们需要将上面的grok转换后的格式关联一个索引模板。

先到`Stack Management`-`索引管理`下面，点击**组件模板**tab页下**创建**相关按钮，填入名称（如golang-logs@mapping），在mapping页面做好映射：

```json
{
  "@timestamp": "Date",
  "log": {
      "level": "Keyword"
  },
  "message": {"Other: match_only_text"}
}
```

然后点击**索引模板**tab页上的按钮，创建一个索引模板，假设名为`golang-logs-template`，在`index patterns`下面填入日志索引的格式，如`logs_golang*`，打开`Create data stream`，并将优先级设置为>100的数值。点击下一步，添加刚才创建的组件模板，添加，在`index settings`中关联ILM：

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

这样就自动将形如`logs-golang*`的索引自动关联到索引模板和生命周期策略上了。

另外提一下，golang的panic日志一般不需要采集，直接用`File Integrity Monitoring Integration`这个集成进行文件监测即可。

### 配置采集器

在`Custom Logs`的添加界面上，命名空间配置当前环境(如`dev`)，点击高级配置，dataset填入服务的名字，如`golang_sip_server`，最后index的名字就是`logs-golang_sip_server-dev`，由于这里已经指定中划线作为分隔符，所以dataset中最好不要出现`-`.

这个名字和`logs-golang*`能够正确匹配上，所以创建的索引会自动关联上去。pipeline需要手动关联，在`Custom configurations`下面，填入如下yaml：

```yaml
pipeline: golang-common-log-parser
```

日志路径可以添加多个，可以使用通配符。

### 确认配置

在Observablity里面正常应该可以看到刚添加的应用日志了。

可以用`event.dataset`搜索上面添加的`golang_sip_server`，看到对应的日志。

## Kibana简单学习

ES的查询语法是复杂的JSON，直接在界面上不方便使用，所以kibana实际上使用了一种名为KQL的方言（DSL）。其使用较为简单，这里记录一下要点：

1. 简单的term匹配，使用`k: v`的形式，多个v可以用空格隔开，表示**或**关系。如果值中包含空格，使用双引号；
2. 允许使用and, or和not逻辑操作，允许使用括号；注意not是放在k前面的，而不是v前面；
3. 数组匹配多个值，使用and，如`tags:(success and info and security)`;
4. 范围查询，支持>, <, = 各种组合；
5. 日期查询一般用右侧的time filter，不过也可以手动写 `@timestamp < "2022-10-10"`之类的，也支持类似influxdb的算术表达式；
6. 允许使用*做模糊匹配，k或者v中都可以；
7.  list of object的匹配，匹配object中的字段，使用大括号。例如`items:{name: banana}`这种；
8. 如果是多级嵌套，如`k1:[{k2: [{"k3": "v"}]]`，搜索的时候需要写全路径，即`k1.k2:{k3: v}`这种搜索；

## 安装Elastic APM

这里的APM其实指的是Trace系统，通过Fleet直接绑定集成就可以。

由于应用还未做好准备，这里先不搞，后续再增补相关步骤。这里的关键在应用改造，集成的难度其实不大。

## 告警配置

下面开始配置告警，告警有很多入口，请根据需要选择：

1. 在可观测性(Observability)里，这里可以设置简单的阈值告警；
2. 在Security-告警里，这里可以使用复杂的表达式从ES中进行各种数据查询并创建告警;
3. 在Stack Management-告警和洞见-Watcher里，这里可以直接用json语句创建告警，这是最灵活的方法；
4. 还是在告警与洞见这里，在规则和连接器里，这里可以设置所有场景的告警，也包括一般的es查询；

### 连接器

告警的发布被称为“连接器”，免费提供的只有kibana日志和写入es index，有三个解决方案：

1. 可以自己写一个简单的工具监控es/kibana日志并调用钉钉发送告警；
2. 使用[ElasticAlert2](https://elastalert2.readthedocs.io/en/latest/elastalert.html)项目；
3. 升级到白金许可证（或者使用[这个项目](https://github.com/wolfbolin/crack-elasticsearch-by-docker)）

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

在安全里可以安装Elastic预构建的几百个规则，不过不是很建议全部导入，因为大部分都没啥用。可以考虑激活k8s，linux之内tag的规则，如果使用云厂商自带的监控，则一般不必再使用这里的告警功能，相当于重复监测了，而且有性能损耗。

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

查询条件仍然是日志等级为ERROR（这里是区分大小写的），这里就是过去5分钟出现任意错误日志则触发。这里在body里面可以拿到`{{context.hits}}`，我们可以通过[mustache](http://mustache.github.io/mustache.5.html)这个模板语言对其内容进行解析。

告警模板：

```json
{
    "msgtype": "markdown",
    "markdown":{
        "title": "Error log found!",
        "text":"在过去3分钟内发现{{context.value}}条错误日志，摘录如下： \n {{#context.hits}} \n **{{_source.event.dataset}}-{{_source.data_stream.namespace}}@{{_source.host.hostname}}:** \n {{_source.@timestamp}}  {{_source.message}} \n {{/context.hits}} \n 点击[此链接]({{context.link}})查看详情。"
    }
}
```

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

watcher属于高级用法，需要自己写全量的JSON来拼凑出表达式，而且也不支持使用已经配置的连接器，有兴趣可以看[这里](https://blog.csdn.net/qq_42259469/article/details/124720184)，官方给出了大量examples，可以参考。这里不太建议使用。

### ElasticStack自身的告警

在告警与洞见里，默认就有一些检测ES本身状态的规则，可以修改。

可以查看日志级别，如果是Warning以上的，可以加一个钉钉通知：

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

点击创建告警，在`Metrics`中点击库存，这里可以对一般指标（cpu、内存等创建告警）。通用告警模板：

```json
{
    "msgtype": "markdown",
    "markdown":{
        "title": "Host CPU Alert",
        "text":"{{context.reason}} \n For detail click [here]({{context.viewInAppUrl}})"
    }
}
```

磁盘空间使用，需要用`system.filesystem.used.pct`这个custom metric.

网络流量、磁盘io告警一般不太好做。

## 看板配置

## K8S采集

## 附录：中间件采集

### nginx

### mysql

### redis cluster

### kafka

### rabbitMQ

### emqx

### influxdb cluster

### seaweedFS

### 阿里云商用中间件