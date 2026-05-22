local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommonModule = require(ReplicatedStorage.Common.CommonModule)

local m = {}

function m.add(a: number, b: number)
	return a + b
end

function m.average(a: number, b: number)
	return CommonModule.divide(a + b, 2)
end

return m
