local Players = game:GetService("Players")
player = Players.LocalPlayer

local Module2 = require(player.PlayerScripts.ClientModule2)

local m = {}

function m.multiply(a: number, b: number)
	return Module2.multiply(a, b)
end

return m
