package stdx_web

import stdx.net.http.*
import stdx.encoding.json.*
import std.collection.*
import std.convert.*
import std.io.{StringReader}
import std.sync.*

public class NoteServer {
    private var service: NoteService
    private var server: ?Server = None

    public init(service: NoteService) {
        this.service = service
    }

    public func start(addr: String, port: UInt16): Unit {
        let svr = ServerBuilder()
            .addr(addr)
            .port(port)
            .build()

        svr.distributor.register("/api/notes", FuncHandler({ ctx =>
            this.handleNotes(ctx)
        }))
        svr.distributor.register("/api/note", FuncHandler({ ctx =>
            this.handleNote(ctx)
        }))
        svr.distributor.register("/api/stats", FuncHandler({ ctx =>
            this.handleStats(ctx)
        }))

        let ready = SyncCounter(1)
        svr.afterBind({ => ready.dec() })

        server = svr
        spawn { svr.serve() }
        ready.waitUntilZero()
    }

    public func stop(): Unit {
        if (let Some(svr) <- server) {
            svr.close()
        }
    }

    public func getPort(): UInt16 {
        if (let Some(svr) <- server) {
            return svr.port
        }
        return 0
    }

    private func handleNotes(ctx: HttpContext): Unit {
        let req = ctx.request
        if (req.method == "POST") {
            try {
                let body = StringReader(req.body).readToEnd()
                let jv = JsonValue.fromStr(body)
                let obj = jv.asObject()
                let title = obj["title"].asString().getValue()
                let content = obj["content"].asString().getValue()
                let jsonTags = obj["tags"].asArray()
                let tags = ArrayList<String>()
                for (i in 0..jsonTags.size()) {
                    tags.add(jsonTags[i].asString().getValue())
                }
                let note = service.createNote(title, content, tags)
                ctx.responseBuilder
                    .header("Content-Type", "application/json")
                    .body(note.toJsonValue().toString())
            } catch (e: Exception) {
                ctx.responseBuilder
                    .status(400)
                    .header("Content-Type", "application/json")
                    .body(##"{"error":"Invalid request body"}"##)
            }
        } else if (req.method == "GET") {
            let query = req.url.rawQuery ?? ""
            let tagParam = getQueryParam(query, "tag")
            var notesList: ArrayList<Note>
            if (let Some(tag) <- tagParam) {
                notesList = service.getNotesByTag(tag)
            } else {
                notesList = service.getAllNotes()
            }
            let result = JsonObject()
            let arr = JsonArray()
            for (note in notesList) {
                arr.add(note.toJsonValue())
            }
            result.put("notes", arr)
            result.put("total", JsonInt(notesList.size))
            ctx.responseBuilder
                .header("Content-Type", "application/json")
                .body(result.toString())
        } else {
            ctx.responseBuilder
                .status(405)
                .header("Content-Type", "application/json")
                .body(##"{"error":"Method not allowed"}"##)
        }
    }

    private func handleNote(ctx: HttpContext): Unit {
        let req = ctx.request
        if (req.method == "GET") {
            let query = req.url.rawQuery ?? ""
            let idStr = getQueryParam(query, "id")
            if (let Some(s) <- idStr) {
                try {
                    let id = Int64.parse(s)
                    if (let Some(note) <- service.getNote(id)) {
                        ctx.responseBuilder
                            .header("Content-Type", "application/json")
                            .body(note.toJsonValue().toString())
                    } else {
                        ctx.responseBuilder
                            .status(404)
                            .header("Content-Type", "application/json")
                            .body(##"{"error":"Note not found"}"##)
                    }
                } catch (e: Exception) {
                    ctx.responseBuilder
                        .status(400)
                        .header("Content-Type", "application/json")
                        .body(##"{"error":"Invalid id parameter"}"##)
                }
            } else {
                ctx.responseBuilder
                    .status(400)
                    .header("Content-Type", "application/json")
                    .body(##"{"error":"Missing id parameter"}"##)
            }
        } else if (req.method == "PUT") {
            try {
                let body = StringReader(req.body).readToEnd()
                let jv = JsonValue.fromStr(body)
                let obj = jv.asObject()
                let id = obj["id"].asInt().getValue()
                let title = obj["title"].asString().getValue()
                let content = obj["content"].asString().getValue()
                let jsonTags = obj["tags"].asArray()
                let tags = ArrayList<String>()
                for (i in 0..jsonTags.size()) {
                    tags.add(jsonTags[i].asString().getValue())
                }
                if (let Some(note) <- service.updateNote(id, title, content, tags)) {
                    ctx.responseBuilder
                        .header("Content-Type", "application/json")
                        .body(note.toJsonValue().toString())
                } else {
                    ctx.responseBuilder
                        .status(404)
                        .header("Content-Type", "application/json")
                        .body(##"{"error":"Note not found"}"##)
                }
            } catch (e: Exception) {
                ctx.responseBuilder
                    .status(400)
                    .header("Content-Type", "application/json")
                    .body(##"{"error":"Invalid request body"}"##)
            }
        } else if (req.method == "DELETE") {
            let query = req.url.rawQuery ?? ""
            let idStr = getQueryParam(query, "id")
            if (let Some(s) <- idStr) {
                try {
                    let id = Int64.parse(s)
                    if (service.deleteNote(id)) {
                        ctx.responseBuilder
                            .header("Content-Type", "application/json")
                            .body(##"{"success":true}"##)
                    } else {
                        ctx.responseBuilder
                            .status(404)
                            .header("Content-Type", "application/json")
                            .body(##"{"error":"Note not found"}"##)
                    }
                } catch (e: Exception) {
                    ctx.responseBuilder
                        .status(400)
                        .header("Content-Type", "application/json")
                        .body(##"{"error":"Invalid id parameter"}"##)
                }
            } else {
                ctx.responseBuilder
                    .status(400)
                    .header("Content-Type", "application/json")
                    .body(##"{"error":"Missing id parameter"}"##)
            }
        } else {
            ctx.responseBuilder
                .status(405)
                .header("Content-Type", "application/json")
                .body(##"{"error":"Method not allowed"}"##)
        }
    }

    private func handleStats(ctx: HttpContext): Unit {
        let stats = service.getStats()
        ctx.responseBuilder
            .header("Content-Type", "application/json")
            .body(stats.toString())
    }
}

func getQueryParam(rawQuery: String, name: String): ?String {
    if (rawQuery.isEmpty()) {
        return None
    }
    let pairs = rawQuery.split("&")
    for (pair in pairs) {
        let parts = pair.split("=")
        if (parts.size >= 2 && parts[0] == name) {
            return parts[1]
        }
    }
    return None
}
