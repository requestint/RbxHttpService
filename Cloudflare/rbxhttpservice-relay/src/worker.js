export default {
    async fetch(request, env) {

        // ── Auth ──────────────────────────────────────────
        const key = request.headers.get("api-key")


        if (key !== env.SECRET_KEY) {
            return Response.json(
                { error: "Unauthorized" },
                { status: 401 }
            )
        }

        // ── Parse incoming batch ──────────────────────────
        let batch


        try {
            batch = await request.json()
        } catch {
            return Response.json(
                { error: "Invalidentifier JSON body" },
                { status: 400 }
            )
        }

        if (!Array.isArray(batch) || batch.length === 0) {
            console.warn("Batch type or length passed is incorrect!")

            return Response.json(
                { error: "Batch must be a non empty array" },
                { status: 400 }
            )
        }

        // ── Fan out all requests in parallel ──────────────
        const results = await Promise.allSettled(
            batch.map(async (entry) => {
                try {
                    const isGet = entry.method === "GET" || entry.method === "HEAD"
                    
                    console.log("SERVER_URL:", env.SERVER_URL)
                    console.log("entry.dest:", entry.dest)
                    console.log("starts with:", entry.dest.startsWith(env.SERVER_URL))

                    const response = await fetch(
                        entry.dest,
                        {
                            method: entry.method,
                            headers: {

                                // only set Content-Type if we're sending a body
                                ...(!isGet && { "Content-Type": "application/json" }),
                                
                                // Authentication and Additional headers
                                "api-key": entry.dest.startsWith(env.SERVER_URL) ? (key || env.SECRET_KEY) : "",
                                "User-Agent": "RbxHttpService/1.0",
                                "Accept": "application/vnd.github+json"
                            },
                            body: isGet ? undefined : (entry.body ?? undefined)
                        }
                    )

                    // handle any response type, not just JSON
                    const contentType = response.headers.get("Content-Type") || ""
                    const data = contentType.includes("application/json")
                        ? await response.json()
                        : await response.text()

                    console.log("Got the following data: ", data)

                    return {
                        identifier: entry.identifier,
                        ok: response.ok,
                        status: response.status,
                        data: data
                    }
                } catch (err) {
                    return {
                        identifier: entry.identifier,
                        ok: false,
                        status: 500,
                        error: err.message
                    }
                }
            })
        )

        // ── Collect results ───────────────────────────────
        const response = results.map(result => {
            if (result.status === "fulfilled") {
                return result.value
            }
            // Promise.allSettled rejected — shouldnt happen
            // since we catch insidentifiere but just in case
            return {
                identifier: "unknown",
                ok: false,
                error: result.reason
            }
        })


        
        return Response.json(response)
    }
}
