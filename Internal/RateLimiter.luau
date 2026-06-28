------------------------
----- [ Modules ] -----
local Log = require("../Helpers/Log")
local configuration = require("../Helpers/Configuration")

------------------------
----- [ Varibles ] -----
local output = "[RateLimiter] %s"
local requestTimes: { number } = {}
local totalTracked = 0
local externalCount = 0

----------------------
----- [ Tables ] -----
local RateLimiter = {}

-----------------------
----- [ Functions ] ---
local function PruneAndCount(): number
	--- Varibles
	local now = os.clock()
	local cutoff = now - 60
	local writeIdx = 1
	local count = 0

	for readIdx = 1, #requestTimes do
		if requestTimes[readIdx] >= cutoff then
			requestTimes[writeIdx] = requestTimes[readIdx]
			writeIdx += 1
			count += 1
		end
	end

	for i = writeIdx, #requestTimes do
		requestTimes[i] = nil
	end

	return count
end

--[[
    @function: RateLimiter:Allow()
        Returns true if a new HTTP request can be made
        without exceeding the rate limit

    @Returns:
        boolean
]]
function RateLimiter:Allow(): boolean
	--- Varibles
	local active = PruneAndCount()

	if active >= configuration.RATE_LIMIT then
		if configuration.DEBUG.LOG_REQUESTS then
			Log("warn", output:format("Rate limit reached (" .. active .. "/" .. configuration.RATE_LIMIT .. ")"))
		end
		return false
	end

	return true
end

--[[
    @function: RateLimiter:Record()
        Records an HTTP request in the sliding window.
        Call this right before (or right after) RequestAsync.
]]
function RateLimiter:Record()
	table.insert(requestTimes, os.clock())
	totalTracked += 1

	Log("print", output:format("request count: " .. totalTracked))
end

--[[
    @function: RateLimiter:WaitForSlot()
        Yields until a rate-limit slot becomes available,
        then records the request atomically.

    @Returns:
        number -- time waited in seconds
]]
function RateLimiter:WaitForSlot(): number
	--- Varibles
	local waited = 0

	while not RateLimiter:Allow() do
		local nextSlot = configuration.FLUSH_INTERVAL
		if #requestTimes > 0 then
			-- Earliest timestamp expires at: requestTimes[1] + 60
			nextSlot = (requestTimes[1] + 60) - os.clock()
		end

		--- Clamp wait time, don't wait more than 5s per iteration
		-- so we can react to config changes or cancel signals
		local waitTime = math.max(0.5, math.min(nextSlot, 5))

		task.wait(waitTime)
		waited += waitTime
	end

	RateLimiter:Record()

	return waited
end

--[[
    @function: RateLimiter:Remaining()
        Returns how many requests can still be made
        in the current 60-second window.

    @Returns:
        number
]]
function RateLimiter:Remaining(): number
	local active = PruneAndCount()
	return math.max(0, configuration.RATE_LIMIT - active)
end

--[[
    @function: RateLimiter:Used()
        Returns the number of requests in the current window.

    @Returns:
        number
]]
function RateLimiter:Used(): number
	PruneAndCount()
	return #requestTimes
end

--[[
    @function: RateLimiter:TotalTracked()
        Lifetime total of requests tracked by this module.

    @Returns:
        number
]]
function RateLimiter:TotalTracked(): number
	return totalTracked
end

--[[
    @function: RateLimiter:RegisterExternal(count?)
        Registers HTTP requests made OUTSIDE this module
        (e.g., other scripts using HttpService directly)
        so the rate limiter can account for them.

    @Options:
        count: number? -- default 1

    @Usage:
        -- Somewhere else in your game:
        local RateLimiter = require(path.to.RateLimiter)
        RateLimiter:RegisterExternal(3) -- 3 requests were made elsewhere
]]
function RateLimiter:RegisterExternal(count: number?)
	--- Varibles
	local NewCount = count or 1

	for _ = 1, NewCount do
		table.insert(requestTimes, (tick() + math.random()) * 2)
		totalTracked += 1
		externalCount += 1
	end
end

--[[
    @function: RateLimiter:ExternalCount()
        Returns how many external requests have been registered.

    @Returns:
        number
]]
function RateLimiter:ExternalCount(): number
	return externalCount
end

return RateLimiter
