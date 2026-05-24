local m = {}

function m.workspaceLocalGameDiscoveryUsesRojoMounts()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local CommonModule = require(ReplicatedStorage.Common.CommonModule)
	local SomeGameModule = require(ServerScriptService.Game.SomeGameModule)
	local SharedGameModule = require(ServerScriptService.Utils.SharedGameModule)

	assert(CommonModule.divide(12, 3) == 4, "12/3 is not 4")
	assert(SomeGameModule.add(5, 7) == 12, "5+7 is not 12")
	assert(SharedGameModule.average(8, 10) == 9, "average(8, 10) is not 9")
end

return m
