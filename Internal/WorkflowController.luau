------------------------
----- [ Services ] -----

-----------------------
----- [ Modules ] -----
local t = require("../Dependencies/t")
local Log = require("../Helpers/Log")
local configuration = require("../Helpers/Configuration")

------------------------
----- [ Varibles ] -----

----------------------
----- [ Tables ] -----
local retry = {}
local res = "[Relay] %s"
local online_entries: { [string]: retry_entry } = {}

----------------------
----- [ Types ] -----
export type retry_entry = {
	identifier: string,
	retry_count: number?,
	coroutine: thread,
	callback: () -> any,
	Release: (err: string) -> (),
}

------------------------
----- [ Functions ] ----
local function Merge(t1, t2)
	assert(type(t1) == "table", "Merge: t1 must be a table")
	assert(type(t2) == "table", "Merge: t2 must be a table")

	for k, v in t2 do
		t1[k] = v
	end

	return t1
end

--[[
    @function: Release
        resumes the awaitting thread putting it in an error state
         by waking the thread with an error response, and then fires the callback
        
         once fully done it'll be removed from online_entries and be removed from memory
    
    @Options: entry: retry_entry, reason: string
      to view these types open this script or do:
         ```lua
            
            local retry = path.to.retry

            type entry = retry.retry_entry
         ```
]]
--
local function Release(entry: retry_entry, reason: string)
	--- type checking & Verification
	assert(t.string(reason))

	if not online_entries[entry.identifier] then
		Log("warn", res:format("Attempted to release already inactive entry: " .. entry.identifier))
		return
	end

	if configuration.DEBUG.LOG_RETRIES then
		Log("warn", res:format("Releasing " .. entry.identifier .. " due to ->> " .. reason))
	end

	--- Waking up the caller
	coroutine.resume(entry.coroutine, nil --[[<< Data result ]], reason --[[<< reason why we are sending an error]])

	--- firing the callback that get's fired when we're releasing a thread
	if entry.Release and type(entry.Release) == "function" then
		entry.Release(reason)
		entry.Release = nil -- < allowing the GC to release it
	end

	--- removing anything related to this entry for the GC to clear it up in memory
	entry.callback = nil
	online_entries[entry.identifier] = nil
	entry = nil
end

--[[
    @function: Attempt
        runs the entry's callback function
        on success resumes the waiting thread with the result
        on failure increments retry count and schedules
        next attempt with exponential backoff
        if max retries exceeded calls Release

    @Options:
        entry : retry_entry
]]
--
local function Attempt(entry: retry_entry)
	--- Vaildation
	if not online_entries[entry.identifier] then
		return
	end
	if configuration.DEBUG.LOG_RETRIES then
		Log(
			"print",
			res:format(
				"Attempting "
					.. entry.identifier
					.. " \n attempt "
					.. (entry.retry_count + 1)
					.. "/"
					.. configuration.RETRY_COUNT
			)
		)
	end

	--- Varibles
	local success, result
	local nextDelay

	--- Running callback in protective thread
	success, result = pcall(entry.callback)

	-- wake the caller with the result if we've a success and a result
	if success and result then
		if configuration.DEBUG.LOG_RETRIES then
			Log(
				"print",
				res:format(entry.identifier .. " succeeded after " .. (entry.retry_count + 1) .. " attempt(s)")
			)
		end

		--- resuming thread for the entry
		coroutine.resume(entry.coroutine, result, nil)

		--- Cleaning up and realeasing stuff to the GC (Garbage Collector)
		entry.callback = nil
		online_entries[entry.identifier] = nil
		entry = nil
		return
	end

	entry.retry_count += 1

	--- Debugging
	if configuration.DEBUG.LOG_RETRIES then
		Log(
			"warn",
			res:format(
				entry.identifier
					.. " failed attempt "
					.. entry.retry_count
					.. "/"
					.. configuration.RETRY_COUNT
					.. " — "
					.. tostring(result)
			)
		)
	end

	--- Out of attempts
	-- release cleanly
	if entry.retry_count >= configuration.RETRY_COUNT then
		Release(entry, "Max retries reached (" .. configuration.RETRY_COUNT .. ") last error: " .. tostring(result))
		return
	end

	--- Calculate next backoff delay
	-- 2s → 4s → 8s and so on...
	nextDelay = configuration.RETRY_DELAY * (2 ^ (entry.retry_count - 1))

	--- Checking for logging conditions
	if configuration.DEBUG.LOG_RETRIES then
		Log("warn", res:format("Retrying " .. entry.identifier .. " in " .. nextDelay .. "s"))
	end

	--- setting a delayed thread retry the entry
	task.delay(nextDelay, function()
		if online_entries[entry.identifier] then
			Attempt(entry)
		else
			if configuration.DEBUG.LOG_RETRIES then
				Log("warn", res:format(entry.identifier .. " was cancelled during backoff, skipping"))
			end
		end
	end)
end

--[[
    @function: retry.Register
        registers a request for the retryRegistery
        fires the first attempt immediately in its own thread
        so registration never blocks the caller

    @Options:
        identifier : string          -- unique id matching the batch entry
        corotinue  : thread          -- coroutine waiting for result
        callback   : () -> any       -- the request function to attempt
        onRelease  : (string) -> ()? -- called if all retries fail

    @Returns:
        nothing — result comes back through the yielded thread
]]
--
function retry.addInRegistery(Options: retry_entry)
	--- Type checking & Verification
	assert(t.string(Options.identifier))
	assert(t.thread(Options.coroutine))
	assert(t.callback(Options.callback))

	if online_entries[Options.identifier] then
		Log("warn", res:format(`Request {Options.identifier} \n is already In Registery! `))
		return
	end

	--- Varibles
	local entry: retry_entry = Merge(Options, { retry_count = 0 })

	--- adding our new unique entry in the online_entries
	online_entries[Options.identifier] = entry

	--- Debug checks
	if configuration.DEBUG.LOG_RETRIES then
		Log("print", res:format("Successfully Added " .. Options.identifier .. " In Registery!"))
	end

	--- Firing entry immediately in a new thread
	task.spawn(Attempt, entry)
end

function retry.ForceQuit(identifer: string, reason: string)
	--- Type checking & Verification
	assert(t.string(identifer))
	assert(t.string(reason))

	--- Varibles
	local request = online_entries[identifer]

	--- we'll check if the entry exists if it does we'll Realease it from memory
	-- using our "Release" function, or we'll warn using our "Log" module to the user
	-- that the given identifier could not reach or be corresponding to any other entry identifier
	if not request then
		Log(
			"warn",
			res:format(
				"Tried to Release / Cancel a Unknown request (and/or Thread). If you believe this was a mistake please look at the concurrent entries"
			)
		)
		return
	else
		Release(request, reason)
	end
end

--[[
    @function: retry.ActiveCount
        returns how many requests are currently
        being tracked for retry

    @Returns:
        number
]]
--
function retry.ActiveCount(): number
	--- Varibles
	local count = 0

	--- Goes through the current entries
	-- and sense they're strings we have to increment our count by 1
	-- for each entry we cycle through
	for _ in pairs(online_entries) do
		count += 1
	end

	return count
end

--[[
    @function: retry.ClearAll
        releases every active request
        useful for cleanup on server shutdown

    @Options:
        reason : string?
]]
--
function retry.ClearAll(reason: string?)
	local count = retry.ActiveCount()

	for _, entry in pairs(online_entries) do
		Release(entry, reason or "Immediate batch CleanUp was requested!")
	end

	Log("warn", res:format("Cleared " .. count .. " active requests"))
end

return retry
