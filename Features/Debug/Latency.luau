local Log = require("../../Helpers/Log")

return function(HttpWrapper, args: {}): number?
	--- Varibles
	local StartTime = os.clock()
	local response, err = HttpWrapper.RequestAsync(args.Url, args.Method, args.Body)

	if response then
		return (StartTime - os.clock())
	else
		Log("error", "[DEBUG] failed to estimate ping due to http error: " .. err)
		return
	end
end
