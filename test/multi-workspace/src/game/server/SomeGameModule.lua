local ServerScriptService = game:GetService("ServerScriptService")
local SharedGameModule = require(ServerScriptService.Utils.SharedGameModule)

local m = {}

function m.add(a: number, b: number)
	return SharedGameModule.add(a, b)
end

return m
