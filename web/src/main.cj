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
