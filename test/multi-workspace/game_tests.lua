local helpers = require("./test_helpers")

local m = {}

function m.workspaceGameRequires()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	assert(ServerScriptService.SomeHubModule == nil)
	assert(ReplicatedStorage.Common.CommonModule ~= nil)
	assert(ServerScriptService.Game.SomeGameModule ~= nil)
	assert(ServerScriptService.Utils.SharedGameModule ~= nil)

	local SomeModule = require(ServerScriptService.Game.SomeGameModule)
	local add = SomeModule.add
	assert(SomeModule.multiply == nil)

	assert(add(1, 1) == 2, "1+1 is not 2")
	assert(add(2, 2) == 4, "2+2 is not 4")
end

function m.gameWorkspaceShared()
	local SharedGameModule = require(helpers.getPath(game, "ServerScriptService", "Utils", "SharedGameModule"))

	assert(SharedGameModule.add(3, 4) == 7, "3+4 is not 7")
	assert(SharedGameModule.average(8, 4) == 6, "average(8, 4) is not 6")
end

return m
