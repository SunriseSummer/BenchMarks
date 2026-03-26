package web

import std.collection.*

// Custom exception for web framework errors
public class WebException <: Exception {
    public init(message: String) {
        super(message)
    }
}

// HTTP method enum
public enum HttpMethod <: Equatable<HttpMethod> & ToString {
    GET | POST | PUT | DELETE | PATCH

    public operator func ==(other: HttpMethod): Bool {
        match ((this, other)) {
            case (GET, GET) => true
            case (POST, POST) => true
            case (PUT, PUT) => true
            case (DELETE, DELETE) => true
            case (PATCH, PATCH) => true
            case _ => false
        }
    }

    public operator func !=(other: HttpMethod): Bool {
        return !(this == other)
    }

    public func toString(): String {
        match (this) {
            case GET => "GET"
            case POST => "POST"
            case PUT => "PUT"
            case DELETE => "DELETE"
            case PATCH => "PATCH"
        }
    }
}

// HTTP request
public class Request {
    public var method: HttpMethod
    public var path: String
    public var headers: HashMap<String, String>
    public var body: String
    public var pathParams: HashMap<String, String>
    public var queryParams: HashMap<String, String>

    public init(method: HttpMethod, path: String) {
        this.method = method
        this.path = path
        this.headers = HashMap<String, String>()
        this.body = ""
        this.pathParams = HashMap<String, String>()
        this.queryParams = HashMap<String, String>()
    }

    public init(method: HttpMethod, path: String, body: String) {
        this.method = method
        this.path = path
        this.body = body
        this.headers = HashMap<String, String>()
        this.pathParams = HashMap<String, String>()
        this.queryParams = HashMap<String, String>()
    }
}

// HTTP response
public class Response {
    public var statusCode: Int64
    public var headers: HashMap<String, String>
    public var body: String

    public init() {
        this.statusCode = 200
        this.headers = HashMap<String, String>()
        this.body = ""
    }

    public func setHeader(name: String, value: String): Unit {
        headers[name] = value
    }
}

// HTTP context wrapping request, response, and services
public class HttpContext {
    public let request: Request
    public let response: Response
    public let services: ServiceContainer

    public init(request: Request, response: Response, services: ServiceContainer) {
        this.request = request
        this.response = response
        this.services = services
    }
}
