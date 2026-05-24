local m = {}

function m.workspaceLocalHubDiscoveryUsesRojoMounts()
	local Players = game:GetService("Players")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ClientModule = require(Players.LocalPlayer.PlayerScripts.ClientModule)
	local SomeHubModule = require(ServerScriptService.SomeHubModule)

	assert(ClientModule.half(14) == 7, "half(14) is not 7")
	assert(SomeHubModule.multiply(3, 5) == 15, "3*5 is not 15")
end

return m
