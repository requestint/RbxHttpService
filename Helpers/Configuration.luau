--[[
	This is a configuration file for the RbxHttpService module
	 Everything here is the setup expected for the module to function
	 You can modify any of these settings to change the behavior of the module
]]
return {
	-- << Endpoints >> --
	SERVER_URL = "https://meticulous-happiness-production-d3ed.up.railway.app",
	database_url = nil, -- Your database URL
	CloudFlareWorkers = {
		"https://rbxhttpservice-relay.studiowork1020.workers.dev",
	} :: { string },

	WorkerAccessKey = nil, -- << " I suggest using secret's that are at least 32 characters long, and contain a mix of letters, numbers, and symbols. If stored in a secret then name it "AuthorizationKey" for the script to detect it via-secret; otherwise you may hard code it IF it's hidden from clients.,
	PublicID = "your-universe-id",

	-- << Request Properties >> --
	FLUSH_INTERVAL = 2, -- seconds between batch flushes
	MAX_BATCH_SIZE = 1, -- If the amount of entires before we start firing the given requests
	RATE_LIMIT = 490,
	MAX_BODY_SIZE = math.huge,
	RequestTimeout = 25,

	-- << Path Settings >> --
	temp = (script.Parent.Parent:FindFirstChild("temp") or "../temp"), -- this is where the objects for stuff like temporary event's and instances will be stored when first created.
	Features = (script.Parent.Parent:FindFirstChild("Features") or "../Features"), -- this is where the feature modules are stored.

	-- << Retry & Release Settings >> --
	RETRY_COUNT = 3, -- max attempts before release
	RETRY_DELAY = 2, -- base delay in seconds, doubles each attempt (2s → 4s → 8s then release)

	-- << Messaging Topics >> --
	TOPICS = {} :: { [string]: string },

	-- << Debug Settings >> --
	DEBUG = {
		ENABLED = true, -- toggles all Logger output
		LOG_REQUESTS = true, -- logs every outgoing request
		LOG_RETRIES = false, -- logs retry attempts and releases
		LOG_BATCH = false, -- logs batch flushes and sizes
		LOG_RATE_LIMIT = false, -- logs when flush is delayed by rate limiter
	} :: { [string]: boolean },
}
