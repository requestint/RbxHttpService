------------------------
----- [ Services ] -----
local MessagingService = game:GetService("MessagingService")

-----------------------
----- [ Modules ] -----
local t = require("../Dependencies/t")
local Log = require("../Helpers/Log")
local Configuration = require("../Helpers/Configuration")

------------------------
----- [ Varibles ] -----

----------------------
----- [ Tables ] -----
local OpenCloud = {}

OpenCloud.__index = OpenCloud
--------------------
----- [ Types ] ----
type HttpWrapper = {
	RequestAsyncParallel: {},
	RequestAsync: (string, string, { [string]: any }) -> any,
} & { [string]: (...any) -> any }

------------------------
----- [ Functions ] ----
function OpenCloud.RegisterHttpWrapper(Wrapper: HttpWrapper)
	-- Vaildation
	assert(t.table(Wrapper))
	assert(t.string(Configuration.PublicID))

	--- Varibles
	local self = setmetatable(OpenCloud, {})
	local Body = {
		UniversalID = Configuration.PublicID,
		Origin = "https://roblox.com/games/" .. game.PlaceId .. "?jobId=" .. game.JobId,
	}

	--- Doing a post request to our back-end to store
	-- the UniversalID to be stored in a database or KV
	local success, result = pcall(Wrapper.RequestAsync, Configuration.database_url, "POST", Body)

	-- returning self so that we can use to call functions like
	-- self:SubscribeToTopic(name, callback)
	return self
end

function OpenCloud:SubscribeToTopic(TopicName: string, func: (...any) -> any)
	--- Varibles
end

return OpenCloud
