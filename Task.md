# 仓颉语言 JsonParser 实现任务书

## 1. 任务目标

使用仓颉（Cangjie）编程语言，**从零实现**一个简单的 JSON 解析器（不使用标准库/扩展库的 JSON 模块），支持：

- **解析**（parse）：将 JSON 字符串解析为内存中的树形数据结构
- **序列化**（serialize）：将树形数据结构转换回紧凑格式的 JSON 字符串
- **构建**（build）：通过 API 手动构建 JSON 数据结构

---

## 2. 项目结构

```
json_parser/
├── cjpm.toml                  # 项目配置
├── src/
│   ├── main.cj                # 入口文件（演示用）
│   ├── json_value.cj          # JSON 值类型定义 + 异常 + 序列化
│   ├── json_parser.cj         # 递归下降解析器
│   └── json_parser_test.cj    # 单元测试
```

### 2.1 项目初始化

```bash
cjpm init --name json_parser --type=executable
```

### 2.2 cjpm.toml 配置

```toml
[package]
  cjc-version = "1.0.5"
  name = "json_parser"
  version = "1.0.0"
  output-type = "executable"
```

---

## 3. API 设计规格

### 3.1 异常类型

```
JsonException <: Exception
  - init(message: String)
```

所有解析错误和类型不匹配操作均抛出 `JsonException`。

### 3.2 值类型层次

```
abstract class JsonValue <: ToString
├── JsonNull       — JSON null
├── JsonBool       — JSON true/false
├── JsonNum        — JSON number（Float64 存储）
├── JsonStr        — JSON string
├── JsonArr        — JSON array
└── JsonObj        — JSON object
```

### 3.3 JsonValue（抽象基类）

| 方法 | 签名 | 说明 |
|------|------|------|
| `isNull` | `public open func isNull(): Bool` | 默认返回 `false` |
| `isBool` | `public open func isBool(): Bool` | 默认返回 `false` |
| `isNumber` | `public open func isNumber(): Bool` | 默认返回 `false` |
| `isString` | `public open func isString(): Bool` | 默认返回 `false` |
| `isArray` | `public open func isArray(): Bool` | 默认返回 `false` |
| `isObject` | `public open func isObject(): Bool` | 默认返回 `false` |
| `asBool` | `public open func asBool(): Bool` | 默认抛出 `JsonException` |
| `asNumber` | `public open func asNumber(): Float64` | 默认抛出 `JsonException` |
| `asString` | `public open func asString(): String` | 默认抛出 `JsonException` |
| `fromString` | `public static func fromString(input: String): JsonValue` | 解析 JSON 字符串 |
| `toString` | `func toString(): String` | 序列化为 JSON 字符串（继承自 `ToString` 接口） |

### 3.4 JsonNull

| 方法 | 行为 |
|------|------|
| `init()` | 无参构造 |
| `isNull()` | 返回 `true` |
| `toString()` | 返回 `"null"` |

### 3.5 JsonBool

| 方法 | 行为 |
|------|------|
| `init(value: Bool)` | 构造布尔值 |
| `isBool()` | 返回 `true` |
| `asBool()` | 返回存储的布尔值 |
| `toString()` | 返回 `"true"` 或 `"false"` |

### 3.6 JsonNum

| 方法 | 行为 |
|------|------|
| `init(value: Float64)` | 构造数值 |
| `isNumber()` | 返回 `true` |
| `asNumber()` | 返回存储的 Float64 值 |
| `toString()` | 整数值输出为 `"42"`（无小数点），浮点值输出为 `"3.14"` 等 |

**数字格式要求**：整数值（如 `42.0`）序列化时**不带小数点**，输出 `"42"`。

### 3.7 JsonStr

| 方法 | 行为 |
|------|------|
| `init(value: String)` | 构造字符串 |
| `isString()` | 返回 `true` |
| `asString()` | 返回存储的字符串（不含引号） |
| `toString()` | 返回带引号和转义的 JSON 字符串，如 `"\"hello\""` |

**序列化转义要求**：`toString()` 须对以下字符进行转义：

| 字符 | 转义输出 |
|------|----------|
| `"` | `\"` |
| `\` | `\\` |
| 换行符 | `\n` |
| 回车符 | `\r` |
| 制表符 | `\t` |

### 3.8 JsonArr

| 方法 | 签名 | 行为 |
|------|------|------|
| `init()` | `public init()` | 构造空数组 |
| `isArray()` | `public override func isArray(): Bool` | 返回 `true` |
| `size()` | `public func size(): Int64` | 返回元素个数 |
| `add(value)` | `public func add(value: JsonValue): Unit` | 追加元素 |
| `get(index)` | `public func get(index: Int64): JsonValue` | 按索引获取元素 |
| `toString()` | `public func toString(): String` | 紧凑格式序列化，如 `[1,2,3]` |

### 3.9 JsonObj

| 方法 | 签名 | 行为 |
|------|------|------|
| `init()` | `public init()` | 构造空对象 |
| `isObject()` | `public override func isObject(): Bool` | 返回 `true` |
| `size()` | `public func size(): Int64` | 返回键值对个数 |
| `get(key)` | `public func get(key: String): ?JsonValue` | 按键获取值，不存在返回 `None` |
| `put(key, value)` | `public func put(key: String, value: JsonValue): Unit` | 添加/覆盖键值对 |
| `containsKey(key)` | `public func containsKey(key: String): Bool` | 检查键是否存在 |
| `keys()` | `public func keys(): ArrayList<String>` | 返回所有键的列表 |
| `toString()` | `public func toString(): String` | 紧凑格式序列化，如 `{"a":1}` |

**对象特性**：
- 保持键的插入顺序
- `put` 对已存在的键执行覆盖操作

---

## 4. 解析器规格

### 4.1 解析入口

```cangjie
let value = JsonValue.fromString(jsonString)
```

### 4.2 解析器类

```cangjie
public class JsonParser {
    public init(text: String)
    public func parse(): JsonValue
}
```

- `parse()` 解析完成后，应检查输入是否已完全消费（忽略尾部空白）
- 输入未完全消费时抛出 `JsonException`

### 4.3 支持的 JSON 语法

| 元素 | 语法示例 | 说明 |
|------|----------|------|
| null | `null` | |
| 布尔 | `true`, `false` | |
| 整数 | `0`, `42`, `-7` | |
| 浮点数 | `3.14`, `-0.5` | |
| 科学计数法 | `1e3`, `1.5e-2`, `2E+5` | |
| 字符串 | `"hello"`, `""` | |
| 字符串转义 | `\"`, `\\`, `\/`, `\n`, `\r`, `\t`, `\b`, `\f` | 标准 JSON 转义 |
| Unicode 转义 | `\u4f60\u597d` → `你好` | 4 位十六进制 |
| 数组 | `[]`, `[1, "a", true]` | |
| 对象 | `{}`, `{"key": "value"}` | |
| 嵌套 | `{"a": [1, {"b": 2}]}` | 任意深度嵌套 |
| 空白 | 空格、制表符、换行、回车 | 结构性空白被忽略 |

### 4.4 不支持的语法（应拒绝）

- 尾部逗号：`[1,]`, `{"a":1,}`
- 单引号字符串：`'hello'`
- 注释：`// comment`, `/* comment */`
- 未加引号的键：`{key: "value"}`
- 解析后输入中有多余非空白字符

### 4.5 解析器实现方式

使用**递归下降**（Recursive Descent）方法实现，建议以 `Array<Rune>`（Unicode 字符数组）作为内部表示来遍历输入字符串，核心方法包括：

- `skipWhitespace()` — 跳过空白字符
- `parseValue()` — 根据当前字符分发到具体的解析方法
- `parseString()` — 解析 JSON 字符串（含转义处理）
- `parseNumber()` — 解析 JSON 数字
- `parseArray()` — 解析 JSON 数组
- `parseObject()` — 解析 JSON 对象
- `parseTrue()` / `parseFalse()` / `parseNull()` — 解析关键字

---

## 5. 序列化规格

所有 `JsonValue` 子类的 `toString()` 方法须生成**紧凑格式**（无空格、无换行）的合法 JSON 字符串。

### 5.1 序列化要求

| 类型 | 输入/构建 | `toString()` 输出 |
|------|-----------|-------------------|
| null | `JsonNull()` | `null` |
| 布尔 | `JsonBool(true)` | `true` |
| 整数 | `JsonNum(42.0)` | `42` |
| 浮点 | `JsonNum(3.14)` | `3.14...`（浮点表示） |
| 字符串 | `JsonStr("hello")` | `"hello"` |
| 含转义字符串 | `JsonStr("a\nb")` | `"a\nb"` |
| 空数组 | `JsonArr()` | `[]` |
| 数组 | `[JsonNum(1.0), JsonNum(2.0)]` | `[1,2]` |
| 空对象 | `JsonObj()` | `{}` |
| 对象 | `{"a": 1, "b": "hello"}` | `{"a":1,"b":"hello"}` |

### 5.2 往返一致性（Round-trip）

对于紧凑格式的合法 JSON 字符串，解析后再序列化应得到**完全相同**的字符串：

```cangjie
let input = ##"{"name":"Alice","age":30,"active":true}"##
let output = JsonValue.fromString(input).toString()
// output == input
```

---

## 6. 单元测试要求

测试文件为 `src/json_parser_test.cj`，使用仓颉单元测试框架（`@Test` / `@TestCase` / `@Assert`）。

### 6.1 测试用例分组

需包含以下 **8 组**测试：

#### 第 1 组：简单值解析（TestParseSimpleValues）

| 测试用例 | 输入 | 验证 |
|----------|------|------|
| 解析 null | `"null"` | `isNull() == true` |
| 解析 true | `"true"` | `isBool() == true`, `asBool() == true` |
| 解析 false | `"false"` | `isBool() == true`, `asBool() == false` |
| 解析整数 | `"42"` | `isNumber() == true`, `asNumber() ≈ 42.0` |
| 解析负整数 | `"-7"` | `asNumber() ≈ -7.0` |
| 解析零 | `"0"` | `asNumber() ≈ 0.0` |
| 解析浮点数 | `"3.14"` | `asNumber() ≈ 3.14` |
| 解析负浮点数 | `"-0.5"` | `asNumber() ≈ -0.5` |
| 解析科学计数法 | `"1e3"` | `asNumber() ≈ 1000.0` |
| 解析带符号科学计数法 | `"1.5e-2"` | `asNumber() ≈ 0.015` |
| 解析简单字符串 | `"\"hello\""` | `asString() == "hello"` |
| 解析空字符串 | `"\"\""` | `asString() == ""` |
| 解析含换行转义 | `"\"hello\\nworld\""` | `asString() == "hello\nworld"` |
| 解析含制表符转义 | `"\"a\\tb\""` | `asString() == "a\tb"` |
| 解析含引号转义 | `"\"say \\\"hi\\\"\""` | `asString() == "say \"hi\""` |
| 解析含反斜杠转义 | `"\"a\\\\b\""` | `asString() == "a\\b"` |
| 解析含斜杠转义 | `"\"a\\/b\""` | `asString() == "a/b"` |
| 解析 Unicode 转义 | `"\"\\u4f60\\u597d\""` | `asString() == "你好"` |
| 解析 UTF-8 字符 | `"\"中文测试\""` | `asString() == "中文测试"` |

#### 第 2 组：空白处理（TestParseWhitespace）

| 测试用例 | 输入 | 验证 |
|----------|------|------|
| 值周围空白 | `"  42  "` | 正常解析为数字 |
| 对象中空白 | `"{ \"a\" : 1 }"` | 正常解析为对象 |
| 换行和制表符 | `"{\n\t\"x\": 1\n}"` | 正常解析为对象 |

#### 第 3 组：数组解析（TestParseArray）

| 测试用例 | 输入 | 验证 |
|----------|------|------|
| 空数组 | `"[]"` | `isArray()`, `size() == 0` |
| 单元素数组 | `"[1]"` | `size() == 1`, 元素值正确 |
| 混合类型数组 | `"[1, \"two\", true, null, 3.14]"` | `size() == 5`, 各元素类型和值正确 |
| 嵌套数组 | `"[[1, 2], [3, 4]]"` | 嵌套结构正确 |

#### 第 4 组：对象解析（TestParseObject）

| 测试用例 | 输入 | 验证 |
|----------|------|------|
| 空对象 | `"{}"` | `isObject()`, `size() == 0` |
| 简单对象 | `"{\"name\": \"Alice\", \"age\": 30}"` | 键值正确 |
| 嵌套对象 | `"{\"a\": {\"b\": 1}}"` | 嵌套结构正确 |
| containsKey | `"{\"key\": \"value\"}"` | `containsKey("key") == true`, `containsKey("missing") == false` |
| get 不存在的键 | `"{\"key\": \"value\"}"` | `get("missing").isNone()` |

#### 第 5 组：复杂 JSON（TestParseComplex）

| 测试用例 | 输入 | 验证 |
|----------|------|------|
| 综合 JSON | 包含字符串、数字、布尔、数组、null 的对象 | 所有字段类型和值正确 |
| 深层嵌套 | `{"a":{"b":{"c":{"d":42}}}}` | 4 层嵌套正确 |
| 对象数组 | `{"items":[{"id":1,"name":"a"},{"id":2,"name":"b"}]}` | 数组中对象的字段正确 |

#### 第 6 组：序列化（TestSerialize）

| 测试用例 | 构建 | 期望输出 |
|----------|------|----------|
| null | `JsonNull()` | `"null"` |
| true | `JsonBool(true)` | `"true"` |
| false | `JsonBool(false)` | `"false"` |
| 整数 | `JsonNum(42.0)` | `"42"` |
| 浮点数 | `JsonNum(3.14)` | 以 `"3.14"` 开头 |
| 字符串 | `JsonStr("hello")` | `"\"hello\""` |
| 含转义字符串 | `JsonStr("a\nb")` | `"\"a\\nb\""` |
| 空数组 | `JsonArr()` | `"[]"` |
| 数组 | 含两个数字 | `"[1,2]"` |
| 空对象 | `JsonObj()` | `"{}"` |
| 对象 | 含数字和字符串 | `"{\"a\":1,\"b\":\"hello\"}"` |

#### 第 7 组：往返测试（TestRoundTrip）

对以下紧凑 JSON 字符串验证 `fromString(s).toString() == s`：

| 输入 |
|------|
| `null` |
| `true` |
| `42` |
| `"hello world"` |
| `[1,2,3]` |
| `{"name":"Alice","age":30}` |
| `{"a":[1,true,null,"hi"],"b":{"c":3}}` |

#### 第 8 组：错误处理（TestErrorHandling）

以下输入应抛出 `JsonException`：

| 测试用例 | 输入 | 错误原因 |
|----------|------|----------|
| 空输入 | `""` | 无内容 |
| 无效 token | `"xyz"` | 非法字符 |
| 未闭合字符串 | `"\"hello"` | 缺少结束引号 |
| 未闭合数组 | `"[1, 2"` | 缺少 `]` |
| 未闭合对象 | `"{\"a\": 1"` | 缺少 `}` |
| 数组尾部逗号 | `"[1,]"` | 尾部逗号 |
| 对象尾部逗号 | `"{\"a\":1,}"` | 尾部逗号 |
| 多余内容 | `"42 extra"` | 解析后有非空白字符 |
| 非法数字 | `"1."` | 小数点后无数字 |
| 缺少冒号 | `"{\"a\" 1}"` | 键后缺少 `:` |

#### 附加组：值构建测试（TestBuildValues）

| 测试用例 | 验证 |
|----------|------|
| 手动构建数组 | `add()` 后 `size()`/`get()` 正确 |
| 手动构建对象 | `put()` 后 `get()`/`size()` 正确 |
| 对象键覆盖 | 同一键 `put` 两次，值被覆盖，`size` 不变 |
| 获取所有键 | `keys()` 返回正确的键列表 |
| 类型检查正交 | 每种类型仅对应的 `isXxx()` 返回 `true` |
| 类型不匹配抛异常 | 对 `JsonNull` 调用 `asBool()`/`asNumber()`/`asString()` 均抛出 `JsonException` |

---

## 7. 入口文件（main.cj）

```cangjie
package json_parser

main(): Int64 {
    let jsonStr = ##"{"name":"Alice","age":30,"active":true,"scores":[90,85,95],"address":null}"##
    let value = JsonValue.fromString(jsonStr)
    println("Parsed JSON:")
    println(value.toString())
    return 0
}
```

期望输出：

```
Parsed JSON:
{"name":"Alice","age":30,"active":true,"scores":[90,85,95],"address":null}
```

---

## 8. 仓颉语言要点提示

以下列出实现本项目时需要注意的仓颉语言特性：

1. **包声明**：每个 `.cj` 文件首行须有 `package json_parser`
2. **导入**：需要 `import std.collection.*`（ArrayList）和 `import std.convert.*`（Float64.parse）
3. **类继承**：使用 `<:` 语法，如 `class JsonNull <: JsonValue`
4. **接口实现**：`JsonValue <: ToString` 要求所有具体子类实现 `toString(): String`
5. **抽象类**：`abstract class` 中无函数体的函数自动为抽象方法
6. **方法覆盖**：父类方法须为 `open`，子类使用 `override`
7. **Option 类型**：`?JsonValue` 等价于 `Option<JsonValue>`，使用 `Some(v)` / `None`
8. **类型窄化**：`v as JsonArr` 返回 `Option<JsonArr>`，需 `.getOrThrow()` 解包
9. **ArrayList**：使用 `add()` 添加，`[i]` 下标访问，`.get(i)` 返回 `Option<T>`
10. **StringBuilder**：高效拼接字符串，支持 `append(String)` / `append(Rune)`
11. **字符串 → 字符数组**：`text.toRuneArray()` 得到 `Array<Rune>`
12. **Rune 比较**：`r'"'`, `r'\\'`, `r'\n'` 等 Rune 字面量支持直接比较
13. **Rune 构造**：`Rune(codePoint)` 从 Unicode 码点创建字符
14. **异常**：自定义异常继承 `Exception`，使用 `super(message)` 调用父类构造
15. **while 循环类型**：`while (true) { ... }` 表达式类型为 `Unit`，函数需在循环后加 `throw` 满足返回类型
16. **数字解析**：`Float64.parse(numStr)` 需要 `import std.convert.*`
17. **原始字符串**：`##"..."##` 语法可包含不转义的引号
18. **单元测试**：`@Test` 标注类，`@TestCase` 标注方法，`@Assert(condition)` 断言

---

## 9. 构建与测试命令

```bash
# 下载仓颉 SDK
curl -L -o cangjie-sdk.tar.gz https://github.com/SunriseSummer/CangjieSDK/releases/download/1.0.5/cangjie-sdk-linux-x64-1.0.5.tar.gz
tar xzf cangjie-sdk.tar.gz
source cangjie/envsetup.sh

# 构建
cjpm build

# 运行
cjpm run

# 测试
cjpm test
```

---

## 10. 验收标准

1. `cjpm build` 编译成功，无错误，无警告
2. `cjpm run` 正确输出解析后的 JSON 字符串
3. `cjpm test` 全部测试通过（约 68 个测试用例，0 失败）
4. 代码结构清晰，文件划分合理
