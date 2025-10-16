---
title: Mybatis Plus自定义枚举
date: 2020-02-18
lastmod: 2020-02-22
slug: d076a8b
draft: false
author:
  name: tryao
tags: ["java"]
collections: []
toc: true
math: true
lightgallery: false
---

# 问题概述

枚举值在db中存储一般是整形或者字符串，在代码里一般是枚举。我们的需求是在model里使用一种自定义类型，能够：

1. 校验用户提供的数据在枚举允许范围内，否则自动报错；
2. 在输出给用户时，json序列化自动加上枚举的中文含义；
3. 自动通过json反序列化到该类型；
4. 存入db时自动转化为对应的整形和字符串；
5. 从db中取出数据时自动转为该自定义类型；

其中1通过自定义validator实现，2/3通过自定义序列化/反序列化实现，4/5通过自定义typeHandler实现。

# 数据字典

枚举值有两种实现方式：写死在代码里，或者使用数据字典存储在db/redis里。下面只介绍数据字典存储在db里的方案，其他几种情况处理手段类似。假设数据字典`sys_dict`包括以下几列：

```java
feat_code   varchar(64)  default ''   not null comment '英文代码',
value_str   varchar(32)  default ''   not null comment '枚举值',
value_cn    varchar(128) default ''   not null comment '枚举值（中文）',
```

并且使用以下服务：

```java
@Service
public class SysDictService extends ServiceImpl<SysDictMapper, SysDict> {
    @Cacheable(cacheNames = Constants.AUTO_CACHE_PREFIX)
    public Map<String, String> getCodeEnums(@NotNull String code) {
        Wrapper<SysDict> wrapper = new QueryWrapper<SysDict>()
                .eq(SysDict.COL_FEAT_CODE, code);
        return this.list(wrapper).stream().collect(
                Collectors.toMap(
                        SysDict::getValueStr,
                        SysDict::getValueCN
                )
        );
    }

    public boolean isValidValue(String key, String value) {
        Wrapper<SysDict> wrapper = new QueryWrapper<SysDict>()
                .eq(SysDict.COL_FEAT_CODE, key)
                .eq(SysDict.COL_VALUE_STR, value);
        return this.getOne(wrapper) != null;
    }
}
```

# 定义自定义类型

## 使用内置枚举类型

mybatis-plus其实内置了这部分支持，不过他是直接将枚举值替换成对应的中文。我们在此基础上进行扩展：

```java
public interface IDictEnum<T extends Serializable> extends IEnum<T> {
    /**
     * 数据库中存储的值
     */
    @JsonValue
    @Override
    T getValue();

    /**
     * 从数据库保存的字典ID
     */
    String getDictCode();
}
```

使用的时候，自定义枚举类型实现上述接口。例如：

```java
public enum CorpKindEnum implements IDictEnum<Integer> {
    CORPORATION(0), GOVERNMENT(1), COMMON(2);

    private Integer v;

    CorpKindEnum(Integer v) {
        this.v = v;
    }

    @Override
    public Integer getValue() {
        return v;
    }

    @Override
    public String getDictCode() {
        return "CORP_KIND_CODE";
    }
}
```

这是一个整形枚举，我们使用`CORP_KIND_CODE`作为`feat_code`，在数据字典里插入对应的值和中文释疑。自定义Json序列化如下：

```java
@Component
public class DictEnumSerializer extends JsonSerializer<IDictEnum> {

    private static SysDictService service;

    //JsonSerializer初始化比bean更早，所以不能直接字段注入
    @Autowired
    public DictEnumSerializer(SysDictService service) {
        DictEnumSerializer.service = service;
    }

    public DictEnumSerializer() {
        super();
    }

    @Override
    public void serialize(IDictEnum value,
                          JsonGenerator generator, SerializerProvider provider)
            throws IOException {
        if (value == null) {
            generator.writeNull();
            return;
        }
        generator.writeObject(value.getValue());
        generator.writeFieldName(generator.getOutputContext().getCurrentName() + "CN");
        generator.writeString(getEnumDesc(value));
    }

    @Override
    public Class handledType() {
        return IDictEnum.class;
    }

    private String getEnumDesc(IDictEnum dictEnum) {
        Map<String, String> map = service.getCodeEnums(dictEnum.getDictCode());
        return map.get(dictEnum.getValue().toString());
    }
}
```

这里在序列化的时候将字段名后面加上`CN`，同时通过数据字典查询对应的中文含义注入。

由于我们这里扩展了mybatis-plus的内置类型，使用时就不需要加上typeHandler的注解了。

**问题**：
jackson在通过整数反序列化到枚举时，无法通过指定的值来反序列化，而是通过整数的顺序(ordinal)来进行的。如果枚举类型不是从0-N这种赋值，则反序列化结果不正确。这是一个存在历史很悠久的[bug](https://github.com/FasterXML/jackson-databind/issues/1850)。

解决方案是在枚举里自定义`JsonCreator`：

```java
@JsonCreator
public static CorpKindEnum fromValue(Integer v) {
 for (CorpKindEnum element : values()) {
       if (element.getValue().equals(v)) {
          return element;
       }
   }
   return null; //or throw exception if you like...
}
```

由于Java语言的限制，我们无法扩展内置的`enum`类型，所以每个自定义枚举上都要自己加上`JsonCreator`。一个简单的解决方案是全部使用字符串枚举，当然这会比使用integer更慢，也比tinyint/smallint更占数据库空间。

## 使用自定义类

上述方案可以解决大部分枚举的问题。但是有些情况下，枚举值特别多，我们又不想在代码里全部列出来，这时候使用内置枚举类型就不太合适了。我们自定义一个抽象类：

```java
@EqualsAndHashCode
@ToString
public abstract class BaseDictValue<T extends Serializable> implements IDictEnum<T> {
    @Setter
    private T value;

    public BaseDictValue(T value) {
        this.value = value;
    }

    @Override
    public T getValue() {
        return value;
    }
}
```

可以看到实际上和刚才的接口是一致的，不再赘述。然后我们实现自定义的typeHandler：

```java
@Slf4j
public class DictValueHandler<E extends BaseDictValue<?>> extends BaseTypeHandler<E> {
    private final Class<E> type;

    public DictValueHandler(Class<E> type) {
        if (type == null) {
            throw new IllegalArgumentException("Type argument cannot be null");
        }
        this.type = type;
    }

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, E e, JdbcType jdbcType) throws SQLException {
        ps.setObject(i, e.getValue());
    }

    private E convertResult(Object vs) {
        if (vs == null) {
            return null;
        }
        try {
            if (vs instanceof Number) { //这里假设枚举只有整数和字符串两种类型，理论上够用了
                return type.getConstructor(Integer.class).newInstance(vs);
            }
            return type.getConstructor(String.class).newInstance(vs);
        } catch (Exception e) {
            log.error("fail to construct dict value", e);
            return null;
        }
    }

    @Override
    public E getNullableResult(ResultSet resultSet, String s) throws SQLException {
        return convertResult(resultSet.getObject(s));
    }

    @Override
    public E getNullableResult(ResultSet resultSet, int i) throws SQLException {
        return convertResult(resultSet.getObject(i));
    }

    @Override
    public E getNullableResult(CallableStatement callableStatement, int i) throws SQLException {
        return convertResult(callableStatement.getObject(i));
    }
}
```

然后自定义序列化仍然复用刚才的即可（因为该抽象类实现了对应的接口）。

最后将刚才的枚举类改成这样：

```java
@EqualsAndHashCode(callSuper = true)
@ToString(callSuper=true)
public class CorpKindEnum extends BaseDictValue<Integer> {
    public static final Integer CORPORATION = 0; //只需要用来解析的一些枚举，不必全部列出所有枚举值了…

    @JsonCreator
    public CorpKindEnum(Integer v) {
        super(v);
    }

    @Override
    public String getDictCode() {
        return "CORP_KIND_CODE";
    }
}
```

这里必须要实现一个单参数构造函数，用来转换对应的基础类型，并将其标注为`@JsonCreator`用来反序列化。

### 注意事项

1. 如果要使用mybatis-plus自带的函数进行增删改查，需要在model的`@TableName`里标注`autoResultMap = true`；并在对应的字段的`@TableField`里标注`typeHandler = DictValueHandler.class`，这样才能正确的进行orm类型转换；
2. 同样，如果自己写resultMap想要进行类型转换，也要在xml里指定上述`typeHandler`。

## 参数校验

这个简单，写一个自定义注解：

```
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = DictFieldValidator.class)
public @interface DictField {
    String message() default "参数错误，枚举值不在允许范围内";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

然后实现校验逻辑：

```java
@Component
public class DictFieldValidator implements ConstraintValidator<DictField, Object> {
    @Autowired
    private SysDictService service;

    @Override
    public boolean isValid(Object o, ConstraintValidatorContext constraintValidatorContext) {
        if (o instanceof IDictEnum) {
            IDictEnum v = (IDictEnum) o;
            return service.isValidValue(v.getDictCode(), v.getValue().toString());
        }
        return false;
    }
}
```

用的时候，在对应的字段上加上`@DictField`注解，对应的类参数前面加上`@Valid`或者`@Validated`就可以了.

## 题外话

1. mybatis-plus自带了一个`JacksonTypeHandler`，可以将数据库字段转换成任意类型，它的原理和上面是一致的。
2. 上述Jackson的`Serializer`需要通过`SimpleModule`手动注册上去。在springboot中可以通过`bean`进行配置。这里给一个参考配置：

```java
@Bean
public ObjectMapper objectMapper() {
    ObjectMapper objectMapper = new ObjectMapper();
    // 对于空的对象转json的时候不抛出错误
    objectMapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS);
    // 禁用遇到未知属性抛出异常
    objectMapper.disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
    // 序列化BigDecimal时不使用科学计数法输出
    objectMapper.configure(JsonGenerator.Feature.WRITE_BIGDECIMAL_AS_PLAIN, true);
    //自定义枚举序列化
    DictEnumSerializer dictEnumSerializer = new DictEnumSerializer();
    SimpleModule simpleModule = new SimpleModule();
    simpleModule.addSerializer(dictEnumSerializer);
    // 日期和时间格式化
    JavaTimeModule javaTimeModule = new JavaTimeModule();
    javaTimeModule.addSerializer(LocalDateTime.class, new LocalDateTimeSerializer(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
    javaTimeModule.addSerializer(LocalDate.class, new LocalDateSerializer(DateTimeFormatter.ofPattern("yyyy-MM-dd")));
    javaTimeModule.addSerializer(LocalTime.class, new LocalTimeSerializer(DateTimeFormatter.ofPattern("HH:mm:ss")));
    javaTimeModule.addDeserializer(LocalDateTime.class, new LocalDateTimeDeserializer(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
    javaTimeModule.addDeserializer(LocalDate.class, new LocalDateDeserializer(DateTimeFormatter.ofPattern("yyyy-MM-dd")));
    javaTimeModule.addDeserializer(LocalTime.class, new LocalTimeDeserializer(DateTimeFormatter.ofPattern("HH:mm:ss")));
    javaTimeModule.addSerializer(Date.class, new DateSerializer(false, new SimpleDateFormat("yyyy-MM-dd HH:mm:ss")));
    objectMapper.registerModule(javaTimeModule);
    objectMapper.registerModule(simpleModule);
    return objectMapper;
}
```
