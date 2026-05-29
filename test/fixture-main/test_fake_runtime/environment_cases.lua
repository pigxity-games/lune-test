local TestHelpers = require("@test/test_helpers")

local assertError = TestHelpers.assertError
local assertErrorContainsOneOf = TestHelpers.assertErrorContainsOneOf
local assertEqual = TestHelpers.assertEqual

local m = {}

function m.servicesAreStableAndConfigurable()
	local env = createEnvironment({
		isStudio = false,
		isServer = true,
		isClient = false,
		datamodel = {
			PrivateServerId = "private-1",
			PrivateServerOwnerId = 77,
		},
		activePlayers = {},
	})

	local runService = env.game:GetService("RunService")
	local collectionService = env.game:GetService("CollectionService")
	local players = env.game:GetService("Players")
	local workspaceService = env.game:GetService("Workspace")
	local memoryStoreService = env.game:GetService("MemoryStoreService")

	assertEqual(runService, env.game:GetService("RunService"))
	assertEqual(collectionService, env.globals.CollectionService)
	assertEqual(players, env.globals.Players)
	assertEqual(workspaceService, env.globals.Workspace)
	assertEqual(memoryStoreService, env.globals.MemoryStoreService)
	assertEqual(env.game:GetService("TeleportService"), nil)
	assertEqual(env.globals.workspace, env.globals.Workspace)
	assert(not runService:IsStudio())
	assert(runService:IsServer())
	assert(not runService:IsClient())
	assertEqual(env.game.PrivateServerId, "private-1")
	assertEqual(env.game.PrivateServerOwnerId, 77)
end

function m.createEnvironmentIsAvailableAsASandboxGlobal()
	assert(type(createEnvironment) == "function")

	local env = createEnvironment({
		isClient = false,
		activePlayers = {},
	})

	assertEqual(env.game:GetService("RunService"):IsClient(), false)
	assertEqual(#env.game:GetService("Players"):GetPlayers(), 0)
	assertEqual(env.globals.workspace, env.globals.Workspace)
end

function m.environmentAvailabilityOverridesAndErrorsAreActionable()
	local env = createEnvironment({
		availableServices = {
			CollectionService = false,
			MemoryStoreService = false,
			Players = false,
			ReplicatedStorage = false,
			ServerScriptService = false,
			StarterPlayer = false,
		},
		availableInstanceTypes = {
			"DataModel",
			"Folder",
			"Instance",
			"RunService",
			"Workspace",
		},
		activePlayers = {},
		serviceOverrides = {
			RunService = {
				IsStudio = function()
					return false
				end,
			},
		},
	})

	assert(not env.game:GetService("RunService"):IsStudio())

	env:overrideService("Workspace", {
		CustomMarker = "override",
	})
	assertEqual(env.game:GetService("Workspace").CustomMarker, "override")

	assertEqual(env.game:GetService("Players"), nil)
	assertEqual(game:GetService("Players"), nil)

	local missingTypeOk, missingTypeError = pcall(function()
		env.Instance.new("RemoteEvent")
	end)
	assert(not missingTypeOk)
	assert(missingTypeError:find("Enabled types") ~= nil)
end

function m.configureAndResetRefreshLiveServicesAndObjects()
	local env = createEnvironment({
		isStudio = true,
		isClient = true,
		isServer = false,
		datamodel = {
			PrivateServerId = "before",
			PrivateServerOwnerId = 5,
		},
		activePlayers = {
			{
				name = "ResetPlayer",
				userId = 303,
				localPlayer = true,
			},
		},
	})
	local runService = env.game:GetService("RunService")
	local playersService = env.game:GetService("Players")
	env:configure({
		isStudio = false,
		isClient = false,
		isServer = true,
		datamodel = {
			PrivateServerId = "after",
			PrivateServerOwnerId = 88,
		},
	})

	assert(not runService:IsStudio())
	assert(not runService:IsClient())
	assert(runService:IsServer())
	assertEqual(env.game.PrivateServerId, "after")
	assertEqual(env.game.PrivateServerOwnerId, 88)

	local oldRunService = runService
	local oldPlayersService = playersService
	local oldLocalPlayer = env.globals.LocalPlayer

	env:reset({
		activePlayers = {},
		isClient = false,
	})

	assert(env.game:GetService("RunService") ~= oldRunService)
	assert(env.game:GetService("Players") ~= oldPlayersService)
	assert(env.globals.LocalPlayer == nil)
	assertEqual(#env.game:GetService("Players"):GetPlayers(), 0)
	assert(oldLocalPlayer ~= env.globals.LocalPlayer)
end

local function setupMultiEnvTest()
	local env1 = createEnvironment({})
	local env2 = createEnvironment({})

	local baseEnvInstance = Instance.new("Folder")
	baseEnvInstance.Name = "BaseEnv"
	baseEnvInstance.Parent = workspace

	local env1Folder = env1.Instance.new("Folder")
	env1Folder.Name = "Env1"
	env1Folder.Parent = env1.globals.workspace

	local env2Folder = env2.Instance.new("Folder")
	env2Folder.Name = "Env2"
	env2Folder.Parent = env2.globals.workspace

	return env1, env2, env1Folder, env2Folder, baseEnvInstance
end

function m.multiEnvironmentParenting()
	local env1, env2, env1Folder, env2Folder = setupMultiEnvTest()

	env2Folder.Parent = workspace
	env1Folder.Parent = env2Folder

	assertEqual(env2Folder.Parent, game:GetService("Workspace"))
	assertEqual(env1Folder.Parent, game:GetService("Workspace"):FindFirstChild("Env2"))

	assert(workspace:FindFirstChild("Env2") ~= nil)
	assert(workspace:FindFirstChild("Env2"):FindFirstChild("Env1") ~= nil)

	assertEqual(env1.globals.workspace:FindFirstChild("Env1"), nil)
	assertEqual(env2.globals.workspace:FindFirstChild("Env2"), nil)
end

function m.environmentInstallUninstall()
	local env1, env2, env1Folder, env2Folder = setupMultiEnvTest()

	local function baseWorkspaceCheck()
		assert(env1 ~= env2)
		assert(env1Folder ~= env2Folder)
		assertEqual(env1Folder.Name, "Env1")

		assertEqual(_G.Test, "HelloWorld")
		assertEqual(workspace:FindFirstChild("Env1"), nil)
		assertEqual(workspace:FindFirstChild("Env2"), nil)
		assert(workspace:FindFirstChild("BaseEnv") ~= nil)
	end

	local function otherWorkspaceCheck(current, other)
		assertEqual(_G.Test, nil)
		assert(workspace:FindFirstChild(current) ~= nil)
		assertEqual(workspace:FindFirstChild("BaseEnv"), nil)
		assertEqual(workspace:FindFirstChild(other), nil)
	end

	_G.Test = "HelloWorld"

	baseWorkspaceCheck()

	env1:install()

	otherWorkspaceCheck("Env1", "Env2")

	env1:uninstall()

	baseWorkspaceCheck()

	env1:install()
	env2:install()

	otherWorkspaceCheck("Env2", "Env1")

	assertError(function()
		env1:uninstall()
	end, "not active")

	env2:uninstall()

	baseWorkspaceCheck()
end

function m.getEnvironmentReturnsCurrentEnvironment()
	local env = getEnvironment()

	assertEqual(env.game:GetService("RunService"), game:GetService("RunService"))
	assertEqual(env.game:GetService("CollectionService"), game:GetService("CollectionService"))
	assertEqual(env.game:GetService("Players"), game:GetService("Players"))
	assertEqual(env.game:GetService("Workspace"), game:GetService("Workspace"))
	assertEqual(env.game:GetService("MemoryStoreService"), game:GetService("MemoryStoreService"))

	local runService = game:GetService("RunService")
	local playersService = game:GetService("Players")

	env:configure({
		isStudio = false,
		isClient = false,
		isServer = true,
		datamodel = {
			PrivateServerId = "after",
			PrivateServerOwnerId = 88,
		},
	})

	assert(not runService:IsStudio())
	assert(not runService:IsClient())
	assert(runService:IsServer())
	assertEqual(env.game.PrivateServerId, "after")
	assertEqual(env.game.PrivateServerOwnerId, 88)

	local oldRunService = runService
	local oldPlayersService = playersService
	local oldLocalPlayer = env.globals.LocalPlayer

	env:reset({
		activePlayers = {},
		isClient = false,
	})

	assert(env.game:GetService("RunService") ~= oldRunService)
	assert(env.game:GetService("Players") ~= oldPlayersService)
	assert(env.globals.LocalPlayer == nil)
	assertEqual(#env.game:GetService("Players"):GetPlayers(), 0)
	assert(oldLocalPlayer ~= env.globals.LocalPlayer)

	assertError(function()
		env:uninstall()
	end, "Cannot uninstall the base environment")
end

function m.servicesAreNotCreatableThroughInstanceNew()
	local env = createEnvironment({
		activePlayers = {},
	})

	for _, className in ipairs({
		"CollectionService",
		"MemoryStoreService",
		"RunService",
		"DataModel",
		"ReplicatedStorage",
		"ServerScriptService",
		"StarterPlayer",
		"StarterPlayerScripts",
		"PlayerScripts",
	}) do
		assertErrorContainsOneOf(function()
			env.Instance.new(className)
		end, {
			"not creatable",
			"cannot be created",
			"Enabled types",
		}, string.format("%s should not be creatable", className))
	end

	assertEqual(env.game:GetService("CollectionService").ClassName, "CollectionService")
	assertEqual(env.game:GetService("MemoryStoreService").ClassName, "MemoryStoreService")
	assertEqual(env.game:GetService("RunService").ClassName, "RunService")
end

function m.dataModelPrivateServerIdentifiersMatchRobloxCases()
	local standard = createEnvironment({
		activePlayers = {},
	})

	assertEqual(standard.game.PrivateServerId, "")
	assertEqual(standard.game.PrivateServerOwnerId, 0)

	local reserved = createEnvironment({
		datamodel = {
			PrivateServerId = "reserved-server-id",
			PrivateServerOwnerId = 0,
		},
		activePlayers = {},
	})

	assert(reserved.game.PrivateServerId ~= "")
	assertEqual(reserved.game.PrivateServerOwnerId, 0)

	local privateServer = createEnvironment({
		datamodel = {
			PrivateServerId = "private-server-id",
			PrivateServerOwnerId = 12345,
		},
		activePlayers = {},
	})

	assert(privateServer.game.PrivateServerId ~= "")
	assertEqual(privateServer.game.PrivateServerOwnerId, 12345)
end

function m.envConfigureGetEnvironment()
	local env = getEnvironment()

	local counter = 0

	env:configure({
		availableServices = {
			RunService = false,
		},
		serviceOverrides = {
			MyCustomService = {
				increment = function()
					counter += 1
				end,
			},
		},
		datamodel = {
			myField = "TestValue",
		},
		globals = {
			myGlobal = "Test",
		},
	})

	assert(game:GetService("ReplicatedStorage") ~= nil)
	assert(game:GetService("RunService") == nil)

	game:GetService("MyCustomService").increment()
	assert(counter == 1)

	assert(myGlobal == "Test")
	assertEqual(game.myField, "TestValue")

	local config = {
		globals = {
			myGlobal = "Something else",
		},
	}

	local env2 = createEnvironment(config)
	assert(env2.config.globals.myGlobal == "Something else")
	assert(env2.config.availableServices.RunService == true)
	assert(table.isfrozen(env2.config))

	assert(myGlobal == "Test")
end

function m.teleportServiceIsRemovedEntirely()
	local env = createEnvironment({
		activePlayers = {},
	})

	assertEqual(env.game:GetService("TeleportService"), nil)
	assertEqual(env:getService("TeleportService"), nil)
	assertError(function()
		env.Instance.new("TeleportOptions")
	end, 'Unsupported fake instance type "TeleportOptions"')
end

function m.rbxScriptSignalUsesNewGlobalNames()
	assertEqual(type(RBXScriptSignal), "table")
	assertEqual(type(RBXScriptConnection), "table")
	assertEqual(Signal, nil)
end

function m.availableServicesRejectsLegacyArrayFormat()
	assertError(function()
		createEnvironment({
			activePlayers = {},
			availableServices = {
				"RunService",
			},
		})
	end, "availableServices must be a set of serviceName = true/false entries")
end

function m.getServiceReturnsNilForUnavailableServices()
	local env = createEnvironment({
		activePlayers = {},
		availableServices = {
			RunService = false,
		},
	})

	assertEqual(env:getService("RunService"), nil)
	assertEqual(env.game:GetService("RunService"), nil)
	assert(env:getService("ReplicatedStorage") ~= nil)
end

return m
