---
title: 解决k8s的javaSDK与jackson不兼容问题
description:
toc: true
authors: ["tryao"]
tags: []
categories: []
series: []
date: 2023-07-10T12:29:45+08:00
lastmod: 2023-07-10T12:29:45+08:00
featuredVideo:
featuredImage:
draft: false
---

k8s的[java sdk](https://github.com/kubernetes-client/java)中json序列化使用了google自家的gosn，但是springboot中默认使用Jackson，我们的业务代码里面也习惯上使用了Jackson。所以直接用k8s sdk会出现各种序列化/反序列化错误，需要做适配。

## 解决方案

其实主要就是修改默认objectMapper的配置：

```java
@Configuration
@AutoConfigureBefore(MvcConfigPlus.class)
public class SpringMvcConf {

    private static void configK8sMapper(ObjectMapper mapper) {
        mapper.addMixIn(V1ListMeta.class, V1ListMetaMixIn.class);
        SimpleModule simpleModule = new SimpleModule();
        IEnumSerializer iEnumSerializer = new IEnumSerializer();
        simpleModule.addSerializer(iEnumSerializer);
        //截断用户输入中的头尾部空格
        simpleModule.addDeserializer(String.class, new StringWithoutSpaceDeserializer());
        //注册k8s object的特殊类
        simpleModule.addSerializer(IntOrString.class, new IntOrStringSerializer());
        simpleModule.addDeserializer(IntOrString.class, new IntOrStringDeserializer());
        mapper.registerModule(simpleModule);
    }

    public static ObjectMapper yamlMapper() {
        ObjectMapper objectMapper = JsonUtils.genYamlObjectMapper();
        configK8sMapper(objectMapper);
        //如果输出yaml，就忽略null字段，减少输出体积
        objectMapper.setDefaultPropertyInclusion(JsonInclude.Include.NON_NULL);
        return objectMapper;
    }

    public static ObjectMapper k8sObjectMapper() {
        ObjectMapper objectMapper = JsonUtils.genCustomObjectMapper();
        configK8sMapper(objectMapper);
        return objectMapper;
    }

    @Bean
    @Primary
    public ObjectMapper objectMapper() {
        return k8sObjectMapper();
    }

    @Bean
    public MappingJackson2HttpMessageConverter mappingJackson2HttpMessageConverter() {
        ObjectMapper mapper = objectMapper();
        MappingJackson2HttpMessageConverter converter = new MappingJackson2HttpMessageConverter();
        converter.setObjectMapper(mapper);
        JacksonTypeHandler.setObjectMapper(mapper);
        return converter;
    }
}
```

因为我们这边的基础库里已经自定义了一个`objectMapper`的bean，所以这里需要用`AutoConfigureBefore`，来保证这边的先初始化（那边的bean上有`@ConditionalOnMissingBean`)。

## 关键字冲突

其中`V1ListMetaMixIn`主要解决`continue`这个字段是java关键字的问题：

```java
@Data
public class V1ListMetaMixIn {
    @JsonIgnore
    private String _continue;
    @JsonProperty("continue")
    private String cursor;
}
```

k8s的sdk里，使用了`_continue`字段来反序列化，这里将其ignore掉，改为`cursor`。

## `IntOrString`问题

yaml中同一个key，value可以是int也可以是字符串，所以k8s有一个`IntOrString`类，需要做特殊处理才能正常序列化/反序列化：

```java
public class IntOrStringSerializer extends StdSerializer<IntOrString> {
    public IntOrStringSerializer() {
        super(IntOrString.class);
    }

    @Override
    public void serialize(IntOrString intOrString, JsonGenerator jsonGenerator, SerializerProvider serializerProvider) throws IOException {
        if (intOrString.isInteger()) {
            jsonGenerator.writeNumber(intOrString.getIntValue());
        } else {
            jsonGenerator.writeString(intOrString.getStrValue());
        }
    }
}
```

```java
public class IntOrStringDeserializer extends JsonDeserializer<IntOrString> {
    @Override
    public IntOrString deserialize(JsonParser jsonParser, DeserializationContext deserializationContext) throws IOException {
        JsonToken currentToken = jsonParser.currentToken();
        if (currentToken == JsonToken.VALUE_NUMBER_INT) {
            return new IntOrString(jsonParser.getIntValue());
        } else if (currentToken == JsonToken.VALUE_STRING) {
            return new IntOrString(jsonParser.getText());
        } else {
            throw new IllegalStateException("Could not deserialize to IntOrString. Was " + currentToken);
        }
    }
}
```

## 忽略null字段

k8s api object中字段非常多，输出到yaml时一般需要忽略掉null字段，所以这里对yaml单独做了配置：

```java
public static ObjectMapper yamlMapper() {
    ObjectMapper objectMapper = JsonUtils.genYamlObjectMapper();
    configK8sMapper(objectMapper);
    //如果输出yaml，就忽略null字段，减少输出体积
    objectMapper.setDefaultPropertyInclusion(JsonInclude.Include.NON_NULL);
    return objectMapper;
}
```

## 兼容yaml和json

springboot可以让同一个API既可以返回json也可以返回yaml，只需要在Controller层设置返回为`ResponseEntity<String>`即可：

```java
public static ObjectMapper genYamlObjectMapper() {
    ObjectMapper mapper = new ObjectMapper(
            new YAMLFactory().disable(YAMLGenerator.Feature.WRITE_DOC_START_MARKER));
    configObjectMapper(mapper);
    return mapper;
}
private static void configObjectMapper(ObjectMapper mapper) {
    // 对于空的对象转json的时候不抛出错误
    mapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);
    // 禁用遇到未知属性抛出异常
    mapper.disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
    mapper.enable(DeserializationFeature.ACCEPT_EMPTY_STRING_AS_NULL_OBJECT);
    mapper.enable(DeserializationFeature.ACCEPT_FLOAT_AS_INT);
    mapper.enable(DeserializationFeature.ACCEPT_SINGLE_VALUE_AS_ARRAY);
    mapper.registerModule(defaultLocalTimeModule());
    mapper.registerModule(defaultSimpleModule());
}
```

```java
public static final String ACCEPT_YAML = "application/x-yaml"; 
@SneakyThrows
public ResponseEntity<String> jsonOrYaml(Object data, boolean yaml) {
    String body = null;
    HttpHeaders headers = new HttpHeaders();
    if (yaml) {
        body = YAML_MAPPER.writeValueAsString(data);
        headers.add(HttpHeaders.CONTENT_TYPE, ACCEPT_YAML);
    } else {
        body = JSON_MAPPER.writeValueAsString(data);
        headers.add(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE);
    }
    return new ResponseEntity<>(body, headers, HttpStatus.OK);
}
```

通过`Content-Type`的header来表明返回的格式。

输入的话兼容起来也很简单：

```java
public class YamlHttpMessageConverter extends AbstractJackson2HttpMessageConverter {
    public YamlHttpMessageConverter() {
        super(JsonUtils.genYamlObjectMapper(), MediaType.parseMediaType("application/x-yaml"));
    }
}
```

然后将其注册到converter里：

```java
@Configuration
public class MvcConfig implements WebMvcConfigurer {
    @Override
    public void extendMessageConverters(List<HttpMessageConverter<?>> converters) {
        converters.add(new YamlHttpMessageConverter());
    }
}
```

这样用户的请求header中`Content-Type`如果是`application/x-yaml`，就会调用Yaml解析器了。当然上面的代码需要一个额外的依赖：

```xml
<dependency>
    <groupId>com.fasterxml.jackson.dataformat</groupId>
    <artifactId>jackson-dataformat-yaml</artifactId>
</dependency>
```

这样才能让Jackson兼容yaml格式。