package stdx_web

import stdx.net.http.*
import std.io.{StringReader}

main(): Int64 {
    let service = NoteService()
    let server = NoteServer(service)
    server.start("127.0.0.1", 0)
    let port = server.getPort()
    let baseUrl = "http://127.0.0.1:${port}"
    println("Server started on port ${port}")

    let client = ClientBuilder().build()

    // Create a note
    let createBody = ##"{"title":"Hello Cangjie","content":"Welcome to Cangjie web programming!","tags":["cangjie","tutorial"]}"##
    let createResp = client.post("${baseUrl}/api/notes", createBody)
    let createResult = StringReader(createResp.body).readToEnd()
    println("Created: ${createResult}")

    // Create another note
    let createBody2 = ##"{"title":"Learning Notes","content":"Studying stdx.net.http and stdx.encoding.json","tags":["cangjie","study"]}"##
    let createResp2 = client.post("${baseUrl}/api/notes", createBody2)
    let createResult2 = StringReader(createResp2.body).readToEnd()
    println("Created: ${createResult2}")

    // List all notes
    let listResp = client.get("${baseUrl}/api/notes")
    let listResult = StringReader(listResp.body).readToEnd()
    println("All notes: ${listResult}")

    // Filter by tag
    let filterResp = client.get("${baseUrl}/api/notes?tag=study")
    let filterResult = StringReader(filterResp.body).readToEnd()
    println("Notes with 'study' tag: ${filterResult}")

    // Get statistics
    let statsResp = client.get("${baseUrl}/api/stats")
    let statsResult = StringReader(statsResp.body).readToEnd()
    println("Stats: ${statsResult}")

    client.close()
    server.stop()
    return 0
}