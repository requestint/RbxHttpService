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
        { error: "Invalid JSON body" },
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
          // << Varibles >>
          const isGet = entry.method === "GET" || entry.method === "HEAD"
          const cacheKey = `http_cache:${entry.method}:${entry.dest}`

          // 1. Only read/write cache for safe retrieval methods (GET/HEAD)
          if (isGet) {
            const cachedBody = await env.KV.get(cacheKey)

            // Checking if we have any retrivable cache
            if (cachedBody !== null) {
              console.log(`Cache HIT for: ${entry.dest}`)

              
              return {
                identifier: entry.identifier,
                ok: true,
                status: 200,
                data: JSON.parse(cachedBody),
                cached: true
              }
            }
          }

          // 2. Cache MISS (or a write method like POST/PATCH/DELETE): Fetch fresh data
          console.log(`Cache MISS or write method. Fetching fresh data for: ${entry.dest}`)
          console.log("SERVER_URL:", env.SERVER_URL)
          console.log("entry.dest:", entry.dest)
          console.log("starts with:", entry.dest.startsWith(env.SERVER_URL))

          const response = await fetch(
            entry.dest,
            {
              method: entry.method,
              headers: {
                ...(!isGet && { "Content-Type": "application/json" }),
                "api-key": entry.dest.startsWith(env.SERVER_URL) ? (key || env.SECRET_KEY) : "",
              },
              body: isGet ? undefined : (entry.body ?? undefined)
            }
          )

          // Handle any response type, not just JSON
          const contentType = response.headers.get("Content-Type") || ""
          const data = contentType.includes("application/json") ? await response.json() : await response.text()
          console.log("Got the following data: ", data)

          // 3. If the network call succeeded and it was a GET request, save it to KV
          if (response.ok && isGet) {
            await env.KV.put(cacheKey, JSON.stringify(data), {
              expirationTtl: 300 // Automatically delete cache data after 5 minutes (300 seconds)
            })
            console.log(`Saved fresh data to KV cache for: ${entry.dest}`)
          }

          return { 
            identifier: entry.identifier, 
            ok: response.ok, 
            status: response.status, 
            data: data,
            cached: false 
          }

        } catch (err) {
          return { identifier: entry.identifier, ok: false, status: 500, error: err.message }
        }
      })
    )

    // ── Collect results ───────────────────────────────
    const responseData = results.map(result => {
      if (result.status === "fulfilled") {
        return result.value
      }
      return { identifier: "unknown", ok: false, error: result.reason }
    })

    return Response.json(responseData)
  }
}
