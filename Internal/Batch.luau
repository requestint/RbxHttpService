------------------------
----- [ Services ] -----
local HttpService = game:GetService("HttpService")

-----------------------
----- [ Modules ] -----
local Log = require("../Helpers/Log")
local configuration = require("../Helpers/Configuration")
local RateLimiter = require("./RateLimiter")
local Serializer = require("./Serializer")
local Promise = require("../Dependencies/Promise")

-----------------------
----- [ Varibles ] -----
local res = "[Batcher] %s"
local flushing: boolean = false
local started: boolean = false
local workerIndex: number = 1

---------------------
----- [ Tables ] -----
local Batcher = {}
local Pending: { BatchFile<{ [string]: any }> } = {}

Batcher.__index = Batcher
--------------------
----- [ Types ] -----
export type BatchFile<body> = {
	identifier: string,
	dest: string,
	TimeStamp: string,
	method: string,
	body: body,
	thread: thread,
}

type RequestAsyncOptions = {
	Url: string,
	Method: string,
	Headers: { [string]: string },
	Body: string,
}

export type Batch_ret = {
	identifier: string,
	content: { [string]: any }?,
	issue: string?,
}

-----------------------
----- [ Functions ] ----
local function GetRoute(): string?
	if #configuration.CloudFlareWorkers == 0 then
		Log("error", res:format("No Cloudflare Workers configured in Config"))
		return nil
	end

	--- Varibles
	local workers = configuration.CloudFlareWorkers
	local url = workers[workerIndex]

	workerIndex = (workerIndex % #workers) + 1

	return url
end

local function SET(operation: string, Struct: { [number]: { [string]: any } })
	--- Vaildation
	if not table.find({ "encode", "decode" }, operation:lower()) then
		return Log(
			"error",
			res:format("Invalid operation for SET function: " .. operation .. " expected 'encode' or 'decode'")
		)
	end

	for _, Struct_res in ipairs(Struct) do
		if Struct_res.body ~= nil or Struct_res.content ~= nil then
			--- Varibles
			local unresolvedbody = Struct_res.body ~= nil and Struct_res.body or Struct_res.content

			--- Checking the format of the body
			if not table.find({ "string", "table" }, type(unresolvedbody)) then
				Log("warn", res:format("Type Error: expected string or table caught: " .. type(unresolvedbody)))
				continue
			end

			--- Getting the operation we're doing
			if operation:lower() == "encode" then
				Struct_res.body = Serializer.write(unresolvedbody)
			else
				Struct_res.content = Serializer.read(Struct_res.body or Struct_res.content)
			end
		elseif Struct_res.method == "POST" and not (Struct_res.body or Struct_res.content) then
			Log(
				"warn",
				res:format(
					"Could not find content or body in the given batch file. Identifier: "
						.. Struct_res.identifier
						.. "\n Timestamp: "
						.. Struct_res.TimeStamp
				)
			)

			return Log(
				"error",
				res:format("Cannot commit POST request due to No content or body found in the given batch file.")
			)
		end
	end

	return Struct
end

local function Construct()
	--- Varibles
	local Struct = {}
	local threads = {}

	--- Getting the Postable content
	-- which we need everything but the thread.
	for _, v in ipairs(Pending) do
		-- print("reading struct: ", v)

		table.insert(Struct, {
			identifier = v.identifier,
			dest = v.dest,
			TimeStamp = v.TimeStamp,
			method = v.method,
			body = v.body,
		})

		table.insert(threads, {
			identifier = v.identifier,
			main = v.thread,
		})
	end

	return Struct, threads
end

local function AwaitRequestAsync(options: RequestAsyncOptions, timeout: number?)
	return Promise.race({
		Promise.delay(timeout):andThen(function()
			return Promise.reject("Request timed out after " .. (timeout or 0) .. " seconds")
		end),

		Promise.new(function(resolve, reject)
			--- Wrapping the RequestAsync in a pcall to catch any potential errors that could occur during the HTTP request
			local success, result = pcall(function()
				return HttpService:RequestAsync({
					Url = options.Url,
					Method = "POST",
					Headers = {
						["Content-Type"] = "application/json",
						["api-key"] = configuration.WorkerAccessKey or HttpService:GetSecret("WorkerAccessKey"),
					},

					Body = options.Body,
				})
			end)

			--- Checking if the HTTP request was successful and if the response indicates a successful status code
			-- if it does we'll resolve the promise with the result, otherwise we'll reject it with an error message
			if success then
				resolve(result)
			else
				reject("HTTP request failed: " .. tostring(result))
			end
		end),
	})
end

local function GetError(response): string?
	--- Varibles
	local err

	-- print("Evaluating response for errors: ", response)

	--- going through each response to see if one had an error, if it did we'll return the error message
	-- typically the responses we'll be sent in an arry
	if response and type(response) == "table" and type(response.data) ~= "table" then
		for _, backend_response in ipairs(response) do
			if backend_response.data and backend_response.data.error then
				err = backend_response.data.error
				break
			end
		end
	end

	return err or nil
end

local function Flush(): string?
	--- Vaildation
	if flushing then
		-- warn("Flusing Is currently occuring! please wait...", #Pending)
		Batcher:WaitInLine()
	end

	if #Pending <= 0 then
		return "Attempted to Flush() when there's nothing to batch!"
	end

	--- Varibles
	local Collection, threads = Construct()
	local bin = SET("Encode", Collection)
	local Route = GetRoute()

	local CurrentEntries = Batcher:ActiveCount()
	local success, result
	local responseMap = {}

	--- Getting The cloudflare worker that'll route my data to my server
	-- and it'll the cloudflare worker will route the data properly without having to worry about limitations
	if not Route then
		for _, entry in ipairs(Collection) do
			coroutine.resume(entry.thread, nil, "No available relay route")
		end

		return "No available relay route"
	end

	--- Setting the state our flush state to true so we don't have flush overlapping
	-- and clearing any un-needed data
	flushing = true

	for entry = 1, math.clamp(CurrentEntries, 1, configuration.MAX_BATCH_SIZE) do
		table.remove(Pending, entry)
	end

	-- print(`sending {CurrentEntries - #Pending} entries!`, CurrentEntries, #Pending)

	--- Wrapping the core flush logic so flushing` always resets
	local ok, err = pcall(function()
		--- Varibles
		local waited = RateLimiter:WaitForSlot()
		local Status: boolean, CompressedData = Serializer.write(bin)

		--- Debug check for rate limit waiting time
		if configuration.DEBUG.LOG_RATE_LIMIT and waited > 0 then
			Log("warn", res:format("Flush was delayed " .. string.format("%.1f", waited) .. "s due to rate limit"))
		end

		--- attempting to post to the cloudflare worker
		success, result = AwaitRequestAsync({
			Url = Route,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = CompressedData:ReadString(),
		}, configuration.RequestTimeout):await()

		--- Checking for any failures
		if success and result.Success and result.Body then
			--- Varibles
			local ok, responses = pcall(Serializer.read, result)

			--- Checking for any failures
			if ok and type(responses) == "table" and not responses.error then
				--- Sending the output how many responses we got
				Log("Print", res:format("Relay response received: (" .. #responses.data .. ") responses"))

				-- Evaulating responses
				for _, resp in ipairs(responses.data) do
					responseMap[resp.identifier] = resp
				end

				--- going through the evaluated responses and responding to the coroutines
				for _, thread in ipairs(threads) do
					--- Varibles
					local resp = responseMap[thread.identifier]

					-- if we have a response
					if resp then
						-- print(GetError(resp), "Relay response received")
						coroutine.resume(thread.main, resp.data, GetError(resp))
					else
						coroutine.resume(thread.main, nil, "No response from relay for identifier")
					end
				end

				Log("print", res:format("Batch completed: " .. #Collection .. " requests"))
			else
				for _, entry in ipairs(threads) do
					coroutine.resume(entry.main, nil, (responses.error or "Invalid relay response body"))
				end

				Log("warn", res:format("Failed to decode relay response: " .. (responses.error or "Unknown")))
			end
		else
			--- Varibles
			local errMsg = if success then "Relay returned error" else tostring(result)

			-- Logging
			Log("warn", res:format("Failed to post to route: " .. errMsg .. " "))

			--- realeasing error to threads
			for _, entry in ipairs(threads) do
				coroutine.resume(entry.main, nil, "Batch flush failed: " .. errMsg)
			end
		end
	end)

	if not ok then
		Log("error", res:format("Flush encountered an internal error: " .. tostring(err)))

		for _, entry in ipairs(Collection) do
			coroutine.resume(entry.thread, nil, "Internal flush error: " .. tostring(err))
		end
	end

	flushing = false
	return
end

function Batcher:WaitInLine()
	repeat
		task.wait()
	until not flushing
end

function Batcher:Add(options)
	--- Varibles
	local thread = coroutine.running()
	local entry = {
		identifier = options.identifier,
		dest = options.dest,
		method = options.method or "GET",
		body = options.body,
		thread = thread,
		TimeStamp = DateTime.now():FormatUniversalTime("LL", "en-us"),
	}

	--- Inserting entry in to our pending table which will be flushed in the next flush cycle
	table.insert(Pending, entry)

	--- Checking if we have reached our max batch size, if we have we'll flush immediately instead of waiting for the next flush cycle
	if #Pending >= configuration.MAX_BATCH_SIZE then
		task.spawn(Flush)
	else
		if configuration.DEBUG.LOG_ENTRY_ADDED then
			Log("print", "Batcher: Entry added to pending table")
		end
		-- Log(
		-- 	"warn",
		-- 	res:format(
		-- 		"Flushing after "
		-- 			.. math.clamp(configuration.MAX_BATCH_SIZE - #Pending, 0, configuration.MAX_BATCH_SIZE)
		-- 			.. " Or more requests Or Until Batcher:Start() Is called!"
		-- 	)
		-- )
	end

	return coroutine.yield()
end

--[[
	@function Batcher:Start()
		Starts the batcher, allowing it to flush pending requests at regular intervals.
		Once started, the batcher will automatically flush pending requests every FLUSH_INTERVAL seconds.
	
	Options (Arguments): None

	return None / nil
]]
function Batcher:Start()
	--- Vaildation
	if started then
		return
	end

	-- setting our batching state to true
	-- so we don't possibly overlap and have 2 batching threads going on during RT (RunTime)
	started = true

	--- Creating a thread to start flushing our pending threads
	-- so that they can be executed on our server off site of roblox
	task.spawn(function()
		while started do
			task.wait(configuration.FLUSH_INTERVAL)

			--- Checking if we have pending requests and if we're not currently flushing
			if self:ActiveCount() > 0 and not flushing then
				self:ForceFlush()
			end
		end
	end)

	Log("print", res:format("Batcher started — flushing every " .. configuration.FLUSH_INTERVAL .. "s"))
end

--[[
	@function Batcher:Stop()
		Stops the batcher, preventing it from flushing pending requests.
		Once stopped, the batcher will cease all automatic flushing of pending requests. 
		Any pending requests that have not yet been flushed will remain in the queue until the batcher is started again or manually flushed.

	Options (Arguments): None

	return None / nil
]]
function Batcher:Stop()
	--- Updaing our started state to false
	-- in the case we ever started our batcher this will force end / quit our thread
	started = false

	-- Logging
	Log("print", res:format("Batcher stopped"))
end

--[[
	@function Batcher:ForceFlush()
		Forces an immediate flush of all pending requests, regardless of the current flush interval or batch size.
		This function can be used to manually trigger a flush of pending requests at any time, such as before shutting down the batcher or when an immediate response is needed.

	Options (Arguments): None

	return None / nil
]]
function Batcher:ForceFlush()
	--- Vaildation
	if self:ActiveCount() == 0 or flushing then
		return
	end

	--- instantly flushing our pending requests
	task.spawn(Flush)
end

--[[
	@function Batcher:ActiveCount()
		Returns the number of pending requests currently queued in the batcher that have not yet been flushed.

	Options (Arguments): None

	return number -- The count of active pending requests in the batcher.
]]
function Batcher:ActiveCount(): number
	return #Pending
end

return Batcher
