# RbxHttpService

A custom HTTP request module for Roblox, built in Luau. It wraps Roblox's built-in `HttpService` with batching, async handling via coroutines, and a relay layer — making external API calls cleaner, safer, and more efficient inside a Roblox game.

---

## Why I Built This

Roblox's default `HttpService` is barebones. It's synchronous, has no built-in batching, and hits rate limits fast if you're firing a lot of requests. I needed something that could:

- Handle multiple requests without blocking the game thread
- Batch outgoing requests to stay under Roblox's HTTP limits
- Route through a Cloudflare Worker relay for auth and rate limiting
- Feel async to the caller without them needing to manage threads

So I wrote it from scratch.

---

## How It Works

Requests go through a simple pipeline:

```
Roblox (RbxHttpService)
    ↓
Cloudflare Workers    — auth, rate limiting
    ↓
Railway (Express)     — middleware, routing
    ↓
Your backend / API
```

Under the hood, RbxHttpService uses Luau coroutines to fake async behavior. When you make a request, the current thread suspends and resumes automatically once the response comes back — no callbacks, no busy-waiting.

Requests are also batched internally, so instead of firing 10 individual HTTP calls, they get grouped and sent together, keeping you well under Roblox's 500 requests/minute limit.

---

## Features

- **Async over coroutines** — callers just `await` a request, the thread handles itself
- **Request batching** — groups outgoing requests to avoid rate limit issues
- **Relay support** — routes through a Cloudflare Worker for auth and security
- **Clean API** — simple to call, no boilerplate needed

---

## Usage

```lua
local RbxHttpService = require(path.to.RbxHttpService)

local response = RbxHttpService:Request({
    Url = "https://your-backend.com/endpoint",
    Method = "POST",
    Body = { key = "value" }
})

print(response.Body)
```

---

## Built By

**Magic** — solo Roblox developer  
GitHub: [github.com/requestint](https://github.com/requestint)