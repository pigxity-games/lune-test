local StatefulModule = require("@src/shared/StatefulModule")

local m = {}

function m.mountsServicesIntoGlobals()
	assert(game:GetService("ReplicatedStorage") == ReplicatedStorage)
	assert(game:GetService("ServerScriptService") == ServerScriptService)
	assert(ReplicatedStorage.UtilModule ~= nil)
	assert(ServerScriptService.SomeModule ~= nil)
end

function m.instanceRequireResolvesNestedModuleScripts()
	local utilModule = require(ReplicatedStorage.UtilModule)
	assert(utilModule.add(3, 4) == 7)
end

function m.moduleStateStartsFreshPerCase1()
	assert(StatefulModule.getCount() == 0)
	assert(StatefulModule.increment() == 1)
	assert(StatefulModule.getCount() == 1)
end

function m.moduleStateStartsFreshPerCase2()
	assert(StatefulModule.getCount() == 0)
	assert(StatefulModule.increment() == 1)
end

function m.serviceTreeStartsFreshPerCase1()
	assert(ReplicatedStorage:FindFirstChild("TransientFolder") == nil)

	local folder = Instance.new("Folder")
	folder.Name = "TransientFolder"
	folder.Parent = ReplicatedStorage

	assert(ReplicatedStorage:FindFirstChild("TransientFolder") == folder)
end

function m.serviceTreeStartsFreshPerCase2()
	assert(ReplicatedStorage:FindFirstChild("TransientFolder") == nil)
end

return m
