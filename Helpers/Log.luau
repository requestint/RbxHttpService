------------------------
----- [ Services ] -----
local Runservice = game:GetService("RunService")

------------------------
----- [ Modules ] -----
local Config = require("./Configuration")

------------------------
----- [ Variables ] ----
local Prefix = "[requestint@RbxHttpService]\n"

return function(method: string, msg: string)
	--- Vaildation
	if not Config.DEBUG.ENABLED and method:lower() ~= "error" then
		return
	end

	--- Varibles
	local Context = Runservice:IsServer() and "[SERVER]" or "[CLIENT]"

	if method:lower():match("error") then
		error(Context .. Prefix .. msg, 2)
	elseif method:lower():match("warn") then
		warn(Context .. Prefix .. msg)
	else
		print(Context .. Prefix .. msg)
	end
end
