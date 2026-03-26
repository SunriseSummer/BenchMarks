# 仓颉语言 Web 服务端框架开发任务书

## 1. 任务目标

使用仓颉（Cangjie）编程语言，实现一个基础的 **Web 服务端框架**，采用现代软件工程和先进 Web 架构设计，支持：

- **依赖注入**（IoC）：提供 `ServiceContainer`，支持 Singleton 和 Transient 生命周期管理
- **中间件管道**（Middleware Pipeline）：洋葱模型中间件链，支持请求前/后处理、短路等
- **路由匹配**（Router）：支持静态路径和带参数的动态路径（如 `/users/:id`）
- **应用框架**（WebApp）：将 IoC、路由、中间件组合为统一的请求处理管道

在框架基础上，还需提供一个**使用示例**（Web 应用），演示框架的各项功能。

> **注意**：本框架的测试采用纯单元测试方式，通过直接构造 `Request`/`Response` 对象并调用 `handleRequest` 来验证，无需启动实际 HTTP 服务器。

---

## 2. 项目结构

```
web/
├── cjpm.toml                  # 项目配置
├── src/
│   ├── main.cj                # 入口文件（使用示例）
│   ├── context.cj             # 异常 + HTTP 方法枚举 + Request/Response/HttpContext
│   ├── container.cj           # IoC 容器（ServiceContainer）
│   ├── router.cj              # 路由器（Router）
│   ├── web_app.cj             # Web 应用框架（WebApp）
│   └── web_test.cj            # 单元测试（已经给定）
```

### 2.1 项目初始化

```bash
cjpm init --name web --type=executable
```

### 2.2 cjpm.toml 配置

```toml
[package]
  cjc-version = "1.0.5"
  name = "web"
  version = "1.0.0"
  output-type = "executable"
```

---

## 3. API 设计规格

### 3.1 异常类型

```
WebException <: Exception
  - init(message: String)
```

所有框架错误（如服务未注册）均抛出 `WebException`。

### 3.2 HTTP 方法枚举

```
enum HttpMethod <: Equatable<HttpMethod> & ToString
  GET | POST | PUT | DELETE | PATCH
```

| 方法 | 说明 |
|------|------|
| `operator func ==(other: HttpMethod): Bool` | 等值比较 |
| `operator func !=(other: HttpMethod): Bool` | 不等比较 |
| `func toString(): String` | 返回方法名称字符串，如 `"GET"`、`"POST"` |

> **注意**：`match` 是仓颉语言关键字，不能用作方法名。如需用作标识符须用反引号转义。

### 3.3 Request（HTTP 请求）

```
class Request
  公开属性：method, path, headers, body, pathParams, queryParams
  - init(method: HttpMethod, path: String)
  - init(method: HttpMethod, path: String, body: String)
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `method` | `HttpMethod` | HTTP 方法 |
| `path` | `String` | 请求路径，如 `"/users/42"` |
| `headers` | `HashMap<String, String>` | 请求头，初始为空 |
| `body` | `String` | 请求体，默认为空字符串 |
| `pathParams` | `HashMap<String, String>` | 路径参数（由路由器填充），初始为空 |
| `queryParams` | `HashMap<String, String>` | 查询参数（由用户手动设置），初始为空 |

- 两个构造函数：无 body 时默认为空字符串
- 所有 `HashMap` 属性在构造时初始化为空
- `pathParams` 由框架在路由匹配时自动填充，用户不应手动设置

### 3.4 Response（HTTP 响应）

```
class Response
  公开属性：statusCode, headers, body
  - init()
  - func setHeader(name: String, value: String): Unit
```

| 属性/方法 | 类型/签名 | 说明 |
|-----------|-----------|------|
| `statusCode` | `Int64` | 状态码，默认 `200` |
| `headers` | `HashMap<String, String>` | 响应头，初始为空 |
| `body` | `String` | 响应体，默认为空字符串 |
| `setHeader` | `(String, String) -> Unit` | 设置响应头（覆盖已有同名头） |

### 3.5 HttpContext（请求上下文）

```
class HttpContext
  公开属性：request, response, services
  - init(request: Request, response: Response, services: ServiceContainer)
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `request` | `Request` | 当前请求（`let` 绑定） |
| `response` | `Response` | 当前响应（`let` 绑定） |
| `services` | `ServiceContainer` | IoC 容器引用（`let` 绑定） |

---

## 4. IoC 容器规格

### 4.1 ServiceLifetime 枚举

```
enum ServiceLifetime
  Singleton | Transient
```

- **Singleton**：首次 `resolve` 时创建实例，后续 `resolve` 返回同一实例（懒创建）
- **Transient**：每次 `resolve` 都创建新实例

### 4.2 ServiceContainer

```
class ServiceContainer
  - init()
  - func register(name: String, factory: () -> Object, lifetime!: ServiceLifetime = Transient): Unit
  - func resolve(name: String): Object
  - func contains(name: String): Bool
```

| 方法 | 说明 |
|------|------|
| `register` | 注册服务工厂函数。`lifetime` 为命名参数，默认 `Transient`。重复注册同名服务时覆盖旧定义并清除已缓存的 Singleton 实例 |
| `resolve` | 按名称解析服务。未注册时抛出 `WebException`。Singleton 在首次调用时懒创建，Transient 每次创建新实例 |
| `contains` | 检查指定名称的服务是否已注册 |

**使用方式**：

```cangjie
// 注册
container.register("userService", { => UserService() }, lifetime: Singleton)

// 解析（返回 Object，需要类型转换）
let svc = (container.resolve("userService") as UserService).getOrThrow()
```

---

## 5. 路由器规格

### 5.1 RouteMatch

```
class RouteMatch
  公开属性：handler, params
  - init(handler: (HttpContext) -> Unit, params: HashMap<String, String>)
```

| 属性 | 类型 | 说明 |
|------|------|------|
| `handler` | `(HttpContext) -> Unit` | 匹配到的路由处理函数 |
| `params` | `HashMap<String, String>` | 从路径中提取的参数键值对 |

### 5.2 Router

```
class Router
  - init()
  - func addRoute(method: HttpMethod, pattern: String, handler: (HttpContext) -> Unit): Unit
  - func findRoute(method: HttpMethod, path: String): ?RouteMatch
```

| 方法 | 说明 |
|------|------|
| `addRoute` | 注册路由规则。`pattern` 支持静态路径和参数路径 |
| `findRoute` | 匹配请求。返回 `?RouteMatch`，无匹配时返回 `None` |

### 5.3 路径匹配规则

| 模式（Pattern） | 请求路径 | 匹配结果 | 提取的参数 |
|------------------|----------|----------|------------|
| `/hello` | `/hello` | ✅ 匹配 | 无 |
| `/hello` | `/world` | ❌ 不匹配 | — |
| `/users/:id` | `/users/42` | ✅ 匹配 | `id = "42"` |
| `/users/:userId/posts/:postId` | `/users/1/posts/99` | ✅ 匹配 | `userId = "1"`, `postId = "99"` |
| `/api/users/:id/profile` | `/api/users/5/profile` | ✅ 匹配 | `id = "5"` |
| `/a/b` | `/a` | ❌ 不匹配（深度不同） | — |
| `/a/b` | `/a/b/c` | ❌ 不匹配（深度不同） | — |
| `/` | `/` | ✅ 匹配 | 无 |

**匹配算法**：

1. 将 `pattern` 和 `path` 按 `"/"` 分割，过滤空段
2. 段数不同则不匹配
3. 逐段比较：以 `:` 开头的段为参数段（捕获值），否则要求精确匹配
4. 按注册顺序，第一个匹配的路由生效
5. HTTP 方法必须一致

---

## 6. 中间件规格

### 6.1 函数类型

```cangjie
// 中间件签名：接收上下文和 next 函数
(HttpContext, () -> Unit) -> Unit
```

### 6.2 执行模型（洋葱模型）

中间件按注册顺序形成嵌套管道，每个中间件可以：

1. 在调用 `next()` 之前执行**请求前处理**
2. 调用 `next()` 将控制权传递给下一个中间件/最终处理函数
3. 在 `next()` 返回后执行**响应后处理**
4. **不调用** `next()` 实现短路（如权限校验失败直接返回 403）

**执行顺序示例**：

```
注册顺序：middleware1 → middleware2 → handler

执行流程：
  middleware1 前处理
    → middleware2 前处理
      → handler 执行
    ← middleware2 后处理
  ← middleware1 后处理
```

### 6.3 中间件链构建

从最后一个中间件向前，逐层包裹处理函数，构建执行链：

```cangjie
var current = handler
var i = middlewares.size - 1
while (i >= 0) {
    let mw = middlewares[i]
    let next = current
    current = { c: HttpContext => mw(c, { => next(c) }) }
    i = i - 1
}
```

---

## 7. WebApp 规格

### 7.1 WebApp 类

```
class WebApp
  公开属性：services
  - init()
  - func use(middleware: (HttpContext, () -> Unit) -> Unit): Unit
  - func get(pattern: String, handler: (HttpContext) -> Unit): Unit
  - func post(pattern: String, handler: (HttpContext) -> Unit): Unit
  - func put(pattern: String, handler: (HttpContext) -> Unit): Unit
  - func delete(pattern: String, handler: (HttpContext) -> Unit): Unit
  - func handleRequest(ctx: HttpContext): Unit
```

| 方法 | 说明 |
|------|------|
| `use` | 注册中间件，按注册顺序执行 |
| `get/post/put/delete` | 注册对应 HTTP 方法的路由处理函数 |
| `handleRequest` | 处理请求：路由匹配 → 填充路径参数 → 构建中间件链 → 执行 |

### 7.2 handleRequest 处理流程

1. 使用 `Router.findRoute` 匹配路由
2. **匹配成功**：将路径参数写入 `ctx.request.pathParams`，使用匹配到的 handler
3. **匹配失败**：使用默认 404 handler（设置 `statusCode = 404`，`body = "Not Found"`）
4. 将所有注册的中间件和 handler 构建为执行链
5. 执行链处理请求

### 7.3 services 属性

`WebApp` 包含一个公开的 `services: ServiceContainer` 属性，在构造时自动创建。所有路由 handler 和中间件可通过 `ctx.services` 访问 IoC 容器。

---

## 8. 单元测试要求

测试文件已经给定为 `web_test.cj`，**不要做修改**，直接引入项目并使用仓颉单元测试框架测试。

测试覆盖以下六大类：

| 测试类 | 测试数量 | 覆盖内容 |
|--------|----------|----------|
| `TestServiceContainer` | 10 | 注册/解析、Singleton/Transient 行为、懒创建、覆盖、多服务、异常 |
| `TestRequest` | 6 | 构造、headers、queryParams、pathParams 初始化、body 默认值 |
| `TestResponse` | 6 | 默认值、状态码、响应体、响应头、多头设置 |
| `TestRouter` | 12 | 精确匹配、参数提取、多参数、方法过滤、根路径、深度不同、空路由 |
| `TestMiddleware` | 8 | 单中间件、执行顺序、响应修改、短路、链式、无中间件、前后处理、服务访问 |
| `TestWebApp` | 10 | GET/POST、404、路径参数、中间件集成、服务注入、多路由、完整管道、PUT/DELETE |

**合计**：52 个测试用例。

---

## 9. 入口文件（main.cj）

```cangjie
package web

import std.collection.*

class GreeterService {
    let _greeting: String
    public init(greeting: String) { _greeting = greeting }
    public func greet(name: String): String { return "${_greeting}, ${name}!" }
}

main(): Int64 {
    let app = WebApp()

    // Register services (IoC)
    app.services.register("greeter", { => GreeterService("Hello") }, lifetime: Singleton)

    // Add logging middleware
    app.use({ ctx: HttpContext, next: () -> Unit =>
        println("[LOG] ${ctx.request.method} ${ctx.request.path}")
        next()
        println("[LOG] Response: ${ctx.response.statusCode}")
    })

    // Add routes
    app.get("/hello", { ctx: HttpContext =>
        ctx.response.body = "Hello, World!"
    })

    app.get("/greet/:name", { ctx: HttpContext =>
        let name = ctx.request.pathParams.get("name").getOrThrow()
        let greeter = (ctx.services.resolve("greeter") as GreeterService).getOrThrow()
        ctx.response.body = greeter.greet(name)
    })

    app.post("/echo", { ctx: HttpContext =>
        ctx.response.body = ctx.request.body
    })

    // Simulate requests
    println("=== Web Framework Demo ===")
    println()

    // GET /hello
    let req1 = Request(HttpMethod.GET, "/hello")
    let ctx1 = HttpContext(req1, Response(), app.services)
    app.handleRequest(ctx1)
    println("Body: ${ctx1.response.body}")
    println()

    // GET /greet/Alice
    let req2 = Request(HttpMethod.GET, "/greet/Alice")
    let ctx2 = HttpContext(req2, Response(), app.services)
    app.handleRequest(ctx2)
    println("Body: ${ctx2.response.body}")
    println()

    // POST /echo
    let req3 = Request(HttpMethod.POST, "/echo", "Hello from client!")
    let ctx3 = HttpContext(req3, Response(), app.services)
    app.handleRequest(ctx3)
    println("Body: ${ctx3.response.body}")
    println()

    // GET /unknown (404)
    let req4 = Request(HttpMethod.GET, "/unknown")
    let ctx4 = HttpContext(req4, Response(), app.services)
    app.handleRequest(ctx4)
    println("Status: ${ctx4.response.statusCode}")
    println("Body: ${ctx4.response.body}")

    return 0
}
```

期望输出：

```
=== Web Framework Demo ===

[LOG] GET /hello
[LOG] Response: 200
Body: Hello, World!

[LOG] GET /greet/Alice
[LOG] Response: 200
Body: Hello, Alice!

[LOG] POST /echo
[LOG] Response: 200
Body: Hello from client!

[LOG] GET /unknown
[LOG] Response: 404
Status: 404
Body: Not Found
```

---

## 10. 实现提示

### 10.1 仓颉语言注意事项

- `match` 是关键字，不能用作方法名（路由器方法建议命名为 `findRoute`）
- `HashMap` 使用 `map[key] = value` 赋值，`map.get(key)` 返回 `Option<V>`，`map.contains(key)` 检查存在性
- `match` 表达式的分支体 `{ ... }` 会被解析为 Lambda；多语句的分支逻辑建议提取为独立方法
- 闭包捕获：在 `while` 循环中构建中间件链时，用 `let` 绑定当前值确保每次迭代捕获正确的引用
- 枚举需显式实现 `Equatable` 接口才能使用 `==` / `!=` 运算符
- 类型转换使用 `(obj as TargetType).getOrThrow()`

### 10.2 建议的文件划分

| 文件 | 内容 |
|------|------|
| `context.cj` | `WebException`、`HttpMethod`、`Request`、`Response`、`HttpContext` |
| `container.cj` | `ServiceLifetime`、`ServiceContainer` |
| `router.cj` | `RouteMatch`、`Router`（及内部辅助类 `RouteEntry`） |
| `web_app.cj` | `WebApp` |
| `main.cj` | 入口文件和示例代码 |

---

## 11. 验收标准

1. `cjpm build` 编译成功，无错误，无警告
2. `cjpm run` 正确输出示例请求的处理结果
3. `cjpm test` 全部测试通过（52 个测试用例，0 失败）
4. 代码结构清晰，文件划分合理
