package web

import std.collection.*

// Result of a route match
public class RouteMatch {
    public let handler: (HttpContext) -> Unit
    public let params: HashMap<String, String>

    public init(handler: (HttpContext) -> Unit, params: HashMap<String, String>) {
        this.handler = handler
        this.params = params
    }
}

// Internal route entry
class RouteEntry {
    let method: HttpMethod
    let segments: ArrayList<String>
    let handler: (HttpContext) -> Unit

    init(method: HttpMethod, pattern: String, handler: (HttpContext) -> Unit) {
        this.method = method
        this.handler = handler
        this.segments = ArrayList<String>()
        for (s in pattern.split("/")) {
            if (s.size > 0) {
                segments.add(s)
            }
        }
    }
}

// Router with path parameter support
public class Router {
    let _routes = ArrayList<RouteEntry>()

    public init() {}

    public func addRoute(method: HttpMethod, pattern: String, handler: (HttpContext) -> Unit): Unit {
        _routes.add(RouteEntry(method, pattern, handler))
    }

    public func findRoute(method: HttpMethod, path: String): ?RouteMatch {
        let pathSegments = ArrayList<String>()
        for (s in path.split("/")) {
            if (s.size > 0) {
                pathSegments.add(s)
            }
        }

        for (route in _routes) {
            if (route.method != method) {
                continue
            }
            if (let Some(params) <- matchSegments(route.segments, pathSegments)) {
                return RouteMatch(route.handler, params)
            }
        }
        return None
    }

    func matchSegments(routeSegs: ArrayList<String>, pathSegs: ArrayList<String>): ?HashMap<String, String> {
        if (routeSegs.size != pathSegs.size) {
            return None
        }
        let params = HashMap<String, String>()
        for (i in 0..routeSegs.size) {
            let rs = routeSegs[i]
            let ps = pathSegs[i]
            if (rs.startsWith(":")) {
                // Extract parameter name (remove leading ':')
                let runes = rs.toRuneArray()
                let sb = StringBuilder()
                for (j in 1..runes.size) {
                    sb.append(runes[j])
                }
                params[sb.toString()] = ps
            } else if (rs != ps) {
                return None
            }
        }
        return params
    }
}
