package web

import std.collection.*

// WebApp: main application class combining IoC, routing, and middleware
public class WebApp {
    public let services: ServiceContainer = ServiceContainer()
    let _router: Router = Router()
    let _middlewares: ArrayList<(HttpContext, () -> Unit) -> Unit> = ArrayList<(HttpContext, () -> Unit) -> Unit>()

    public init() {}

    // Register a middleware function
    public func use(middleware: (HttpContext, () -> Unit) -> Unit): Unit {
        _middlewares.add(middleware)
    }

    // Register route handlers for each HTTP method
    public func get(pattern: String, handler: (HttpContext) -> Unit): Unit {
        _router.addRoute(HttpMethod.GET, pattern, handler)
    }

    public func post(pattern: String, handler: (HttpContext) -> Unit): Unit {
        _router.addRoute(HttpMethod.POST, pattern, handler)
    }

    public func put(pattern: String, handler: (HttpContext) -> Unit): Unit {
        _router.addRoute(HttpMethod.PUT, pattern, handler)
    }

    public func delete(pattern: String, handler: (HttpContext) -> Unit): Unit {
        _router.addRoute(HttpMethod.DELETE, pattern, handler)
    }

    // Process a request through the middleware pipeline and route handler
    public func handleRequest(ctx: HttpContext): Unit {
        // Match route
        let matchResult = _router.findRoute(ctx.request.method, ctx.request.path)

        var handler: (HttpContext) -> Unit = { c: HttpContext =>
            c.response.statusCode = 404
            c.response.body = "Not Found"
        }

        if (let Some(rm) <- matchResult) {
            for ((k, v) in rm.params) {
                ctx.request.pathParams[k] = v
            }
            handler = rm.handler
        }

        // Build middleware chain from inside out
        var current = handler
        var i = _middlewares.size - 1
        while (i >= 0) {
            let mw = _middlewares[i]
            let next = current
            current = { c: HttpContext => mw(c, { => next(c) }) }
            i = i - 1
        }

        // Execute the chain
        current(ctx)
    }
}
