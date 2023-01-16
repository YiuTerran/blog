---
title: Golang服务接入OpenTelemetry
description:
toc: true
authors: []
tags: []
categories: []
series: []
date: 2022-12-05T11:12:41+08:00
lastmod: 2022-12-05T11:12:41+08:00
featuredVideo:
featuredImage:
draft: false

---

三大支柱中，Log是最简单的，metric也不难。对于golang而言，最麻烦的是trace，这时候就分外羡慕java这种可以自动注入的语言了。

## 基本设计

首先是一个Trace Provider，用来实例化Tracer。某些语言里Provider和Tracer都是全局预创建好的。

Trace Exporter，类似metric，但是是push到collector，而非pull.

Trace Context，即上下文。Tracer 创建span，将attribute注入其中，后续的span可以通过connect by trace id的方法将新的上下文注入其中，并通过parent span id进行排序。

所以核心的概念就是trace（标识请求）和span（标识一个上下文），两者分别有一个id. 默认情况下trace id是16字节，span id是8字节。

一个span的例子：

```json
{
  "trace_id": "7bba9f33312b3dbb8b2c2c62bb7abe2d",
  "parent_id": "",
  "span_id": "086e83747d0e381e",
  "name": "/v1/sys/health",
  "start_time": "2021-10-22 16:04:01.209458162 +0000 UTC",
  "end_time": "2021-10-22 16:04:01.209514132 +0000 UTC",
  "status_code": "STATUS_CODE_OK",
  "status_message": "",
  "attributes": {
    "net.transport": "IP.TCP",
    "net.peer.ip": "172.17.0.1",
    "net.peer.port": "51820",
    "net.host.ip": "10.177.2.152",
    "net.host.port": "26040",
    "http.method": "GET",
    "http.target": "/v1/sys/health",
    "http.server_name": "mortar-gateway",
    "http.route": "/v1/sys/health",
    "http.user_agent": "Consul Health Check",
    "http.scheme": "http",
    "http.host": "10.177.2.152:26040",
    "http.flavor": "1.1"
  },
  "events": [
    {
      "name": "",
      "message": "OK",
      "timestamp": "2021-10-22 16:04:01.209512872 +0000 UTC"
    }
  ]
}
```

Log和Metric的概念比较容易理解，这里不再赘述，除此之外，还有一个概念：`Baggage`。假设某个span的上下文里有个变量需要分享给其他span，可以使用Baggage机制来进行分享。需要注意的是Baggage中的变量并不会自动加到attributes。

## 使用范例

在已经完成的golang程序里引入如下两个包：

```bash
go get go.opentelemetry.io/otel \
       go.opentelemetry.io/otel/trace
```

go里面的trace系统主要依赖context包，通过

```go
newCtx, span := otel.Tracer(name).Start(ctx, "Run")
```

通过name创建一个Tracer，然后创建一个名为`Run`的新span。然后将这个newCtx当做参数向下传递，在函数逻辑完成之前调用`span.End()`结束逻辑。

而将trace导出以供查看，需要初始化`Exporter`，配置Collector的地址等属性，如果只是为了调试，也可以输出到console上。

对Service本身的标记（微服务的名称、实例ip等），使用`Resource`来初始化。



如果想降低性能影响，不需要采样所有的trace，可以使用`sdktrace.WithSampler`来选择采样方案。

最后，使用TracerProvider将这些配置相关联，使用`otel.SetTracerProvider`初始化tracer，完整的初始化流程如下：

```go
import (
	"context"
	"crypto/tls"
	"fmt"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/exporters/stdout/stdouttrace"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.12.0"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
	"os"
	"strings"
	"time"
)

type TraceParam struct {
	ServiceName     string  // 服务名称
	ServiceVersion  string  // 版本号，避免服务版本不一致问题
	ServiceInstance string  // 示例标识，pod id或者ip:port之类的
	Environment     string  // dev, test, prod之类
	Endpoint        string  // host:port
	Authorization   string  // basic auth或者api key
	Protocol        string  // http或者grpc
	EnableTLS       bool    //是否使用ssl
	CertFile        string  //证书路径，使用tls时才需要配置
	SampleRate      float64 //默认为1
}
// InitProvider 初始化并返回provider
func InitProvider(param TraceParam, asGlobal bool) (*sdktrace.TracerProvider, error) {
	if param.ServiceName == "" || param.ServiceVersion == "" {
		return nil, fmt.Errorf("invalid service param to init tracer")
	}
	//默认是生产环境
	if param.Environment == "" {
		param.Environment = "prod"
	}
	ctx := context.Background()
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String(param.ServiceName),
			semconv.ServiceVersionKey.String(param.ServiceVersion),
			semconv.ServiceInstanceIDKey.String(param.ServiceInstance),
			semconv.DeploymentEnvironmentKey.String(param.Environment),
		),
		resource.WithHost(),
		resource.WithProcess(),
		resource.WithTelemetrySDK(),
		resource.WithSchemaURL(semconv.SchemaURL),
	)
	if err != nil {
		return nil, fmt.Errorf("fail to create resource:%w", err)
	}
	var exporter sdktrace.SpanExporter
	if param.Endpoint == "" {
		//兜底策略，控制台输出
		exporter, err = stdouttrace.New(
			stdouttrace.WithWriter(os.Stdout),
			stdouttrace.WithPrettyPrint(),
		)
	} else if param.Protocol == ProtocolGRPC {
		//连接collector超时时间
		ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		opts := []grpc.DialOption{grpc.WithBlock()}
		if !param.EnableTLS {
			opts = append(opts, grpc.WithTransportCredentials(insecure.NewCredentials()))
		} else {
			//tls证书
			var creds credentials.TransportCredentials
			if param.CertFile != "" {
				creds, err = credentials.NewClientTLSFromFile(param.CertFile, "")
				if err != nil {
					return nil, fmt.Errorf("init grpc conn to apm server err:%s", err)
				}
			} else {
				return nil, fmt.Errorf("you should specific CertFile when enable tls with grpc")
			}
			opts = append(opts, grpc.WithTransportCredentials(creds))
		}
		conn, err := grpc.DialContext(ctx, param.Endpoint, opts...)
		if err != nil {
			log.Fatal("fail to init grpc conn to apm server:%s", err)
		}
		exporter, err = otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
		if err != nil {
			return nil, fmt.Errorf("fail to create trace exporter:%w", err)
		}
	} else {
		var tlsConf otlptracehttp.Option
		if param.EnableTLS {
			tlsConf = otlptracehttp.WithTLSClientConfig(&tls.Config{InsecureSkipVerify: true})
		} else {
			tlsConf = otlptracehttp.WithInsecure()
		}
		exporter, err = otlptracehttp.New(context.Background(),
			otlptracehttp.WithEndpoint(param.Endpoint),
			tlsConf,
		)
		if err != nil {
			return nil, fmt.Errorf("fail to create http exporter:%w", err)
		}
	}
	bsp := sdktrace.NewBatchSpanProcessor(exporter)
	traceProvider := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(
			sdktrace.ParentBased(sdktrace.TraceIDRatioBased(param.SampleRate)),
		),
		sdktrace.WithResource(res),
		sdktrace.WithSpanProcessor(bsp),
	)
	if asGlobal {
		otel.SetTracerProvider(traceProvider)
	}
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{}))
	return traceProvider, nil
}
```

这相当于设置了一个全局的traceProvider，也可以在创建tracer的时候手动指定provider。如果使用sdk的话，对应的包是sdktrace.

常用golang基础库都有社区提供的trace版，其包格式一般为：

```bash
go get go.opentelemetry.io/contrib/instrumentation/{import-path}/otel{package-name}
```

## Elastic APM使用

其实就是在Fleet里面安装一个apm server充当collector，然后在go这边配置对接就行。

elastic apm对接openTelemetry还有一些bug，不过总体是可用的。

elastic自己的sdk只对接了很少一部分第三方库，用起来并不是很方便。

es的apm server支持[尾采样](https://www.elastic.co/guide/en/apm/guide/current/sampling.html#tail-based-sampling)，可以更有效的采样异常数据，推荐使用。

需要注意的是，es在kafka等MQ使用场景中注入的是二进制的header，而不是text版本，需要自己写代码进行解析：

```go
// ExtractW3CBinaryTraceParent 从w3c trace-context-binary 格式中解析trace parent
// [link](https://github.com/w3c/trace-context-binary/blob/571cafae56360d99c1f233e7df7d0009b44201fe/spec/20-binary-format.md)
func ExtractW3CBinaryTraceParent(bs []byte) (spanCxt trace.SpanContext, err error) {
	if len(bs) < 29 {
		err = fmt.Errorf("trace parent length error")
		return
	}
	version := bs[0]
	switch version {
	case 0:
		if bs[1] != 0 || bs[18] != 1 || bs[27] != 2 {
			return spanCxt, fmt.Errorf("format error")
		}
		spanCxt = spanCxt.WithTraceID(*(*[16]byte)(bs[2:18])).
			WithSpanID(*(*[8]byte)(bs[19:27])).
			WithTraceFlags(trace.TraceFlags(bs[28]))
		return spanCxt, err
	default:
		return spanCxt, fmt.Errorf("unknown trace version")
	}
}

// ExtractW3CBinaryTraceState 从w3c trace-context-binary 格式中解析trace state
// 对应的字符串格式是k1=v1,k2=k2
func ExtractW3CBinaryTraceState(bs []byte) (state trace.TraceState, err error) {
	if len(bs) <= 2 {
		return state, nil
	}
	idx := 0
	kvs := make([]string, 0)
	for {
		if idx >= len(bs) {
			break
		}
		if bs[idx] != 0 {
			return state, fmt.Errorf("format error")
		}
		keyLen := int(bs[idx+1])
		if keyLen == 0 {
			break
		}
		key := string(bs[idx+2 : idx+2+keyLen])
		valueLen := int(bs[idx+2+keyLen])
		value := string(bs[idx+keyLen+3 : idx+keyLen+3+valueLen])
		kvs = append(kvs, fmt.Sprintf("%s=%s", key, value))
		idx = idx + keyLen + 3 + valueLen
	}
	return trace.ParseTraceState(strings.Join(kvs, ","))
}

// ToW3CBinary 序列化成w3c二进制
func ToW3CBinary(sxt trace.SpanContext) (traceParent, traceState []byte) {
	traceParent = make([]byte, 29)
	traceParent[18] = 1
	traceParent[27] = 2
	traceId := [16]byte(sxt.TraceID())
	copy(traceParent[2:18], traceId[:])
	if sxt.SpanID().IsValid() {
		spanId := [8]byte(sxt.SpanID())
		copy(traceParent[19:27], spanId[:])
	}
	traceParent[28] = byte(sxt.TraceFlags())
	if sxt.TraceState().Len() > 0 {
		s := sxt.TraceState().String()
		pairs := strings.Split(s, ",")
		for _, pair := range pairs {
			kv := strings.Split(pair, "=")
			if len(kv) != 2 {
				continue
			}
			traceState = append(traceState, 0, byte(len(kv[0])))
			traceState = append(traceState, []byte(kv[0])...)
			traceState = append(traceState, byte(len(kv[1])))
			traceState = append(traceState, []byte(kv[1])...)
		}
	} else {
		traceState = []byte{0, 0}
	}
	return
}
```

## 需要注意的坑

golang中使用context.Context传递trace上下文，所以一般是请求过来之后将入口的context往下传递即可。但是context.Context的主要作用并不是传递trace，而是用来控制超时(timeout)和请求取消(cancel)，所以如果新的goroutine里直接传递外围的context，很可能会遇到`Context Canceled`问题。

解决方案也很简单，使用：

```go
	spanCtx := trace.SpanContextFromContext(ctx)
	return trace.ContextWithSpanContext(context.Background(), spanCtx)
```

将trace上下文从中取出，创建一个新的context即可。

在使用grpc或者http服务时，尤其需要注意这个问题。

## 附：常用Trace字段

OpenTelemetry约定了一系列常用的Trace字段，应对不同的场景，参考[这里](https://opentelemetry.io/docs/reference/specification/trace/semantic_conventions/)，截止目前还是Experimental状态，所以后面还会有新的变动。 建议脑子里有个大致的概念就行，需要的时候再按图索骥，东西有点多。大部分基础库都内置了相关机制，只需要传入context即可。

可以使用`go.opentelemetry.io/otel/semconv/v1.12.0`在代码中使用下面这些常量。

### 网络请求一般字段

```js
{
    net:{
        transport: ip_tcp, //or ip_udp, pipe, inproc, other
        app:{
            protocol:{
                name: "http",
                version: "2.0"
            },
        },
        sock:{
            peer:{
                name: "www.xxx.com",
                addr: "127.0.0.1",
                port: 23333,
            },
            family: "inet", //or inet6, unix
            host:{
                addr: "192.168.0.1",
                port: 35555,
                connection:{
                    type: "wifi", //wired, cell, unavailable, unknown
                    subtype: "LTE" //gprs, edge, umts, cdma, evdo_0, evdo_a, cdma2000_1xrtt, hsdpa, hsupa, hspa, iden, evdo_b, ehrpd, hspap, gsm, td_scdma, iwlan, nr, nrnas, lte_ca
                },
                carrier:{
                    name: "sprint",
                    mcc: "310",
                    mnc: "001",
                    icc: "DE"
                }
            }
        },
        peer:{
            name: "xxx.com",
            port: 80,
        },
        host:{
            name: "localhost",
            port: 8080,
        },
        
    }
}
```

需要注意`net.sock.peer`/`net.sock.host`和`net.peer`/`net.host`的区别。后者是逻辑上的本端和对端，如果两者相同，则应该优先设置`net.sock.*`。 简单来说，如果是tcp/udp的底层通信协议，则应该只设置`net.sock.*`；如果使用mqtt/http这些高层协议，则应当设置`net.*`，同时尽量设置可以拿到的`net.sock.*`.

此外，当通过代理进行通信时，`net.*`应当设置为目的地址，`net.socket.*`应当设置为代理地址。

### 远程请求一般字段

```json
{
    peer:{
        service: ""
    }
}
```

即对端服务名称，可以随意命名，业务上根据自己需求来。

### 一般身份字段

```js
{
    enduser:{
        id: "", //终端用户身份id，或者用户名
        role: "", //角色，如admin
        scope: "", //作用域权限，如read:message, write:files
    }
}
```

### 一般线程字段

```js
{
    thread:{
        id: "", //线程id
        name: "",//线程名称
    }
}
```

### 源码相关字段

```js
{
    code:{
        "function": "", //函数名称
        "namespace": "", //包名之类的，有些语言有命名空间
        "filepath": ""// 源码路径
        "lineno": 100, //源码行数
    }
}
```

这块一般在日志里。

### HTTP请求常用字段

影响span本身的字段：

name：虽然一般用url，但是也可以自定义

status：一般是http响应状态

通用属性字段：

```js
{
    http:{
        method: "POST",
        status_code: "",
        flavor: "1.0", //也可以是SPDY/QUIC等
        user_agent: "", //UA
        request_content_length: 3495, //请求体字节数
        response_content_length: 3000, //响应体字节数
    }
}
```

以及一部分`net.sock.*`的属性。

header可以通过`http.request.header.<key>`以及`http.response.header.<key>`来注入header字段。

客户端专用字段：

```js
{
    http:{
        url: "", //不能包含basic auth的认证信息
        resend_count: 1,
    }
}
```

以及net.peer.*相关字段。

服务端专用字段：

```js
{
    http:{
        scheme: "https",
        target: "/path/1234",
        route: "/usrs/:usrId", //如果有的话
        client_ip: "", //原始地址，并非代理地址       
    }
}
```

以及net.host和net.sock.host相关字段。

### 数据库客户端常用字段

数据库本身：

```js
{
    db:{
        system: "mysql",
        connection_string: "", //连接地址，移除认证数据部分
        user: "root",
    }
}
```

以及net相关的字段。

语言或者具体数据相关的字段：

```js
{
    db:{
        jdbc.driver_classname: "", //only for java
        mssql:{
            instance_name: "", //sql server的示例名
        }
    }
}
```

请求相关：

```js
{
    db:{
        name: "", //库名
        statement: "", //请求语句
        operation: "SELECT", //操作类型，动词
    }
}
```

具体数据相关的请求上下文：

```js
{
    db:{
        "redis.database_index": 0, //redis库
        "mongodb.collection": "customers", //mongo的表名
        "sql.table": "customers", //dbms的表名
    }
}
```

某些字段需要根据具体的数据库来决定。

### RPC相关字段

span名称**必须**是远程调用的全名：`$package.$service/$method`，其他常用字段：

```js
{
    rpc:{
        system: "grpc", //apache_dubbo, java_rmi, dotnet_wcf
        service: "", //含有包名
        method: "", //方法名
    }
}
```

消息相关：

```js
{
    message:{
        type: "SENT", //RECEIVED
        id: 1, //消息唯一标识
        compressed_size: 2000, //压缩后字节数
        uncompressed_size: 3200, //原始字节数
    }
}
```

grpc专用：

```js
{
    rpc:{
        grpc:{
            status_code: int, //grpc有一系列预定于的状态码，从0开始
        },
        request_metadata:{
            key1: "",
            key2: ""
        },
        response_metadata:{
            key1: "",
            key2: ""
        }
    }
}
```

json rpc专用：略，现在一般不怎么用了。

### MQ等消息系统

MQ一般被抽象为生产者、中间代理和消费者三个部分。

span name的一般格式为：`<dest name> <op name>`， 例如`shop.orders send`, `shop.orders receive`和`shop.orders process`.

消息属性：

```js
{
    messaging:{
        system: "kafka", //MQ名称
        destination: "topic-name",
        destination_kind: "queue", //or topic
        temp_destination: true, //是否临时目的地
        protocol: "MQTT", //AMQP等
        protocol_version: "0.9.1", //协议版本
        url: "", //MQ的连接字符串
        message_id:"", //消息id
        conversation_id: "" //会话id
        message_payload_size_bytes: 2738, //未压缩的原始字节数
        message_payload_compressed_size_bytes: 1730, //压缩后的字节数
    }
}
```

对于消息接收者的额外属性：

```js
{
    messaging:{
        operation: "receive", //或者process
        consumer_id: "", //对于kafka，设置为`messaging.kafka.consumer_group`-`messaging.kafka.client_id`; 其他的一般clint_id就够了
    }
}
```

特定mq属性字段：

```js
{
    messaging:{
        "rabbitmq.routing_key": "",
        kafka:{
            message_key: "", //非空才设置
            consumer_group: "", //消费组, only for consumer
            client_id: "",
            partition: 1, //消息发送的分区
            tombstone: true, //如果一条消息的key不为null，但其value为null，那么此消息就是墓碑消息，       用于清理日志
        },
        rocketmq:{
            namespace: "",
            client_group: "",
            client_id: "",
            delivery_timestamp: 1665987217045, //毫秒级时间戳
            delay_time_level: 3, //延迟级别
            message_group: "", //FIFO消息需要
            message_type: "normal", //fifo, delay, transaction
            message_tag: "",
            message_keys: [],
            consumption_model: "clusering", //broadcasting
        }
    }
}
```

### FaaS调用

即Serverless的lambda函数，这里从略，因为用的不多。

### 异常相关字段

异常不能记录在event域，必须记录在exception域。

```js
{
    exception:{
        escaped: true,
        message: "", //消息
        stacktrace: "", //堆栈
        type: "OSError", //异常类
        
    },
}
```

## 
