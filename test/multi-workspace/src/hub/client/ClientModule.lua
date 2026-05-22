local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommonModule = require(ReplicatedStorage.Common.CommonModule)

local m = {}

function m.half(value: number)
	return CommonModule.divide(value, 2)
end

return m
