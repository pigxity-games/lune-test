local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UtilModule = require(ReplicatedStorage.UtilModule)

local m = {}

function m.add(a: number, b: number)
	return UtilModule.add(a, b)
end

return m
