local helpers = require("./test_helpers")

local m = {}

function m.workspaceHubRequires()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	assert(helpers.getPath(ServerScriptService, "Game", "SomeGameModule") == nil)
	assert(ReplicatedStorage.Common.CommonModule ~= nil)
	assert(helpers.getPath(ServerScriptService, "Utils", "SharedGameModule") == nil)

	local SomeModule = require(ServerScriptService.SomeHubModule)
	local multiply = SomeModule.multiply

	assert(SomeModule.add == nil)
	assert(multiply(2, 4) == 8, "2*4 is not 8")
	assert(multiply(16, 4) == 64, "16*4 is not 64")
end

function m.hubWorkspaceClientRequires()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local ClientModule = require(player.PlayerScripts.ClientModule)

	assert(ClientModule.half(8) == 4, "half(8) is not 4")
	assert(ClientModule.half(18) == 9, "half(18) is not 9")
end

return m
