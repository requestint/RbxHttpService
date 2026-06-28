------------------------
----- [ Services ] -----
local HttpService = game:GetService("HttpService")

------------------------
----- [ Varibles ] -----

-----------------------
----- [ Modules ] -----
local WorkflowController = require("./Internal/WorkflowController")
local Batcher = require("./Internal/Batch")
local t = require("./Dependencies/t")
local Configuration = require("./Helpers/Configuration")

----------------------
----- [ Tables ] -----
local RbxHttpService = {}
local Exclusions = { "Features" }

RbxHttpService.__index = RbxHttpService
RbxHttpService.Batcher = Batcher
RbxHttpService.Workflow = WorkflowController
RbxHttpService.Features = {}

----------------------
----- [ Types ] -----
type RequestOptions = { url: string, method: string, body: { [string]: any }? }

------------------------
----- [ Functions ] ----
function SetFeatures(Origin: Folder)
	for _, Child in (Origin ~= nil and Origin or Configuration.Features):GetChildren() do
		if Child:IsA("Folder") then
			RbxHttpService.Features[Child.Name] = {}
			SetFeatures(Child)
			continue
		end

		-- Checking if we're ignoring any folders specifically when indexing
		-- for example I don't want to have a index "Features.Features" instead I want Features.OpenCloud
		-- so I just index the OpenCloud module as it's own
		if not table.find(Exclusions, Child.Parent.Name) then
			RbxHttpService.Features[Child.Parent.Name][Child.Name] = require(Child)
		else
			RbxHttpService.Features[Child.Name] = require(Child)
		end
	end
end

--[[
    Function: RbxHttpService.RequestAsync(RequestOptions)
     Description: Get's the Information / Body from a given endpoint URL destination

    Options (Arguments):
		RequestOptions:
		  url: string
		  method: string
		  body: {[string]: any}? << ONLY USE IF YOU'RE DOING A POST REQUEST

    return any
]]
--
function RbxHttpService.RequestAsync(Options: RequestOptions)
	--- Vaildation
	assert(t.string(Options.url), "RbxHttpService.RequestAsync: url must be a string")
	assert(t.string(Options.method), "RbxHttpService.RequestAsync: method must be a string")

	--- Varibles
	local Identifier = HttpService:GenerateGUID(false)
	local thread = coroutine.running()

	-- now we're gonna add the request to the workflow controller, and then yield the thread until we get a response back from the server
	WorkflowController.addInRegistery({
		identifier = Identifier,
		coroutine = thread,
		callback = function(response)
			return Batcher:Add({
				identifier = "req_" .. Identifier,
				dest = Options.url,
				method = Options.method,
				body = Options.body,
			})
		end,

		Release = function(error)
			-- if the request is released, we're gonna resume the thread with nil, indicating that the request was released and no response will be coming back
			coroutine.resume(thread, nil, error)
		end,
	})

	--- now we'll wait for a response to come back and return it
	return coroutine.yield()
end

--[[
    Function: RbxHttpService.RequestAsyncParallel(RequestOptions)
     Description: Allow's you to do serveral requests all at once 
		 for example you can do one for auth, database, and etc
			 

    Options (Arguments): { [number]: RequestOptions }

    return { Response: { any } or err: string? }
]]
--
function RbxHttpService.RequestAsyncParallel(Requests: { RequestOptions }): { any }
	--- Varibles
	local temp = Configuration.temp
	local total_to_compile = #Requests
	local results = table.create(total_to_compile)
	local CompletedRequests = Instance.new("BindableEvent", temp)

	--- Now we'll call our basic "RequestAsync" function in seperate thread's
	-- so that we don't have to do 1 at a time and wait for a return on every single one individually
	for index, request in Requests do
		task.spawn(function()
			--- Varibles
			local data, err = RbxHttpService.RequestAsync(request)

			--- now we'll add in our entry
			results[index] = {
				response = data,
				err = (err or nil),
			}

			-- decreasing by 1 to show how much more we need to compile
			total_to_compile -= 1

			-- checking if we fully completed all entries
			if total_to_compile <= 0 then
				CompletedRequests:Fire()
				Batcher:Stop()
			end
		end)
	end

	Batcher:Start()

	-- waitting for our requests to be done
	-- once done we'll destroy the event sense we're no longer using it
	CompletedRequests.Event:Wait()
	CompletedRequests:Destroy()

	return results
end

SetFeatures()

return RbxHttpService
