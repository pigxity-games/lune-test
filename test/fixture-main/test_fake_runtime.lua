local m = {}

local function assertEqual(actual, expected, message)
	assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

local function assertSequenceEqual(actual, expected, label)
	assertEqual(#actual, #expected, string.format("%s length mismatch", label or "sequence"))

	for index, expectedValue in ipairs(expected) do
		assertEqual(actual[index], expectedValue, string.format("%s mismatch at index %d", label or "sequence", index))
	end
end

local function assertNameSetEqual(actual, expectedNames, label)
	assertEqual(#actual, #expectedNames, string.format("%s length mismatch", label or "name set"))

	local seen = {}
	for _, instance in ipairs(actual) do
		seen[instance.Name] = (seen[instance.Name] or 0) + 1
	end

	for _, expectedName in ipairs(expectedNames) do
		assertEqual(seen[expectedName], 1, string.format("%s missing %s", label or "name set", expectedName))
	end
end

local function assertContains(haystack: string, needle: string, label)
	assert(
		haystack:find(needle, 1, true) ~= nil,
		label or string.format('expected "%s" to contain "%s"', haystack, needle)
	)
end

local function assertError(fun, contains)
	local ok, err = pcall(fun)
	assert(not ok)
	assertContains(err, contains)
end

function m.servicesAreStableAndConfigurable()
	local env = createEnvironment({
		isStudio = false,
		isServer = true,
		isClient = false,
		privateServerId = "private-1",
		privateServerOwnerId = 77,
		activePlayers = {},
	})

	local runService = env.game:GetService("RunService")
	local collectionService = env.game:GetService("CollectionService")
	local players = env.game:GetService("Players")
	local workspaceService = env.game:GetService("Workspace")
	local memoryStoreService = env.game:GetService("MemoryStoreService")
	local teleportService = env.game:GetService("TeleportService")

	assertEqual(runService, env.game:GetService("RunService"))
	assertEqual(collectionService, env.globals.CollectionService)
	assertEqual(players, env.globals.Players)
	assertEqual(workspaceService, env.globals.Workspace)
	assertEqual(memoryStoreService, env.globals.MemoryStoreService)
	assertEqual(teleportService, env.globals.TeleportService)
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

function m.instanceHierarchyAttributesAndSignals()
	local env = createEnvironment({
		activePlayers = {},
	})
	local root = env.Instance.new("Model")
	local folder = env.Instance.new("Folder")
	local tool = env.Instance.new("Tool")
	local part = env.Instance.new("Part")
	local value = env.Instance.new("NumberValue")
	local childAddedNames = {}
	local childRemovedNames = {}
	local attributeChanges = {}
	local propertyChanges = {}
	local changedValues = {}

	root.Name = "Root"
	folder.Name = "Inventory"
	tool.Name = "Hammer"
	part.Name = "Handle"
	value.Name = "Coins"

	root.ChildAdded:Connect(function(child)
		table.insert(childAddedNames, child.Name)
	end)

	root.ChildRemoved:Connect(function(child)
		table.insert(childRemovedNames, child.Name)
	end)

	part:GetAttributeChangedSignal("Health"):Connect(function()
		table.insert(attributeChanges, part:GetAttribute("Health"))
	end)

	part:GetPropertyChangedSignal("Position"):Connect(function()
		table.insert(propertyChanges, tostring(part.Position))
	end)

	value.Changed:Connect(function(newValue)
		table.insert(changedValues, newValue)
	end)

	folder.Parent = root
	tool.Parent = root
	part.Parent = tool
	value.Parent = root

	assertSequenceEqual(childAddedNames, { "Inventory", "Hammer", "Coins" }, "child added order")
	assertEqual(root:FindFirstChild("Inventory"), folder)

	assertEqual(root:FindFirstChildOfClass("Tool"), tool)
	assertEqual(tool:FindFirstChildWhichIsA("BasePart"), part)
	assertEqual(tool:FindFirstChildOfClass("Part"), part)

	assertEqual(tool:FindFirstChildWhichIsA("BasePart"), part)
	assertEqual(tool:FindFirstChildOfClass("Part"), part)
	assertEqual(tool:FindFirstChildOfClass("BasePart"), nil)

	assertEqual(#root:GetChildren(), 3)
	assertEqual(#root:GetDescendants(), 4)
	assert(part:IsA("BasePart"))

	assertEqual(root:FindFirstChildWhichIsA("BasePart"), nil)
	assertEqual(root:FindFirstChildWhichIsA("BasePart", true), part)

	part.Position = Vector3.new(1, 2, 3)
	assertEqual(part.CFrame.Position.X, 1)
	assertEqual(part.CFrame.Position.Y, 2)
	assertEqual(part.CFrame.Position.Z, 3)
	part.CFrame = CFrame.new(4, 5, 6)
	assertEqual(part.Position.X, 4)
	assertEqual(part.Position.Y, 5)
	assertEqual(part.Position.Z, 6)
	assertSequenceEqual(propertyChanges, { "1, 2, 3", "4, 5, 6" }, "position changes")

	part:SetAttribute("Health", 100)
	part:SetAttribute("Health", 200)
	assertSequenceEqual(attributeChanges, { 100, 200 }, "attribute changes")
	assertEqual(part:GetAttribute("Health"), 200)

	local healthRemoved = false

	part:GetAttributeChangedSignal("HealthRemovedTest"):Connect(function()
		healthRemoved = part:GetAttribute("HealthRemovedTest") == nil
	end)

	part:SetAttribute("HealthRemovedTest", 10)
	part:SetAttribute("HealthRemovedTest", nil)

	assertEqual(part:GetAttribute("HealthRemovedTest"), nil)
	assert(healthRemoved)

	value.Value = 15
	assertSequenceEqual(changedValues, { 15 }, "number value changes")

	local waited = nil
	env.task.spawn(function()
		waited = root:WaitForChild("AsyncFolder", 1)
	end)
	env.task.defer(function()
		local asyncFolder = env.Instance.new("Folder")
		asyncFolder.Name = "AsyncFolder"
		asyncFolder.Parent = root
	end)
	env.scheduler:flush()
	assertEqual(waited.Name, "AsyncFolder")

	local ok, err = pcall(function()
		root.Parent = part
	end)
	assert(not ok)
	assert(err:find("descendants") ~= nil)

	folder:Destroy()
	assertSequenceEqual(childRemovedNames, { "Inventory" }, "child removed order")
	assert(root:FindFirstChild("Inventory") == nil)
end

function m.signalDisconnectPreventsFurtherFires()
	local signal = Signal.new("StandaloneSignal")
	local fired = 0
	local connection = signal:Connect(function()
		fired += 1
	end)

	signal:Fire()
	connection:Disconnect()
	signal:Fire()

	assertEqual(fired, 1)
	assertEqual(signal:GetConnectionCount(), 0)
end

function m.signalDisconnectAllAndDisconnectDuringFire()
	local signal = Signal.new("ComplexSignal")
	local order = {}
	local secondConnection

	signal:Connect(function()
		table.insert(order, "first")
		secondConnection:Disconnect()
	end)

	secondConnection = signal:Connect(function()
		table.insert(order, "second")
	end)

	local thirdConnection = signal:Connect(function()
		table.insert(order, "third")
	end)

	signal:Fire()
	assertSequenceEqual(order, { "first", "third" }, "re-entrant disconnect order")
	assertEqual(signal:GetConnectionCount(), 2)

	signal:DisconnectAll()
	assertEqual(signal:GetConnectionCount(), 0)

	order = {}
	signal:Fire()
	assertEqual(#order, 0)
	assert(not thirdConnection.Connected)
end

function m.collectionServiceTracksTagsAndCleanup()
	local env = createEnvironment({
		activePlayers = {},
	})
	local collectionService = env.game:GetService("CollectionService")
	local first = env.Instance.new("Folder")
	local second = env.Instance.new("Folder")
	local added = {}
	local removed = {}

	first.Name = "First"
	second.Name = "Second"
	first.Parent = env.globals.Workspace
	second.Parent = env.globals.Workspace

	collectionService:GetInstanceAddedSignal("Enemy"):Connect(function(instance)
		table.insert(added, instance.Name)
	end)
	collectionService:GetInstanceRemovedSignal("Enemy"):Connect(function(instance)
		table.insert(removed, instance.Name)
	end)

	collectionService:AddTag(first, "Enemy")
	collectionService:AddTag(first, "Enemy")
	collectionService:AddTag(second, "Enemy")

	local lateAdded = 0

	collectionService:GetInstanceAddedSignal("Enemy"):Connect(function()
		lateAdded += 1
	end)

	assertEqual(lateAdded, 0)

	assertNameSetEqual(collectionService:GetTagged("Enemy"), { "First", "Second" }, "tagged instances")
	assert(collectionService:HasTag(first, "Enemy"))
	assertSequenceEqual(added, { "First", "Second" }, "added tags")

	first:AddTag("Direct")
	assert(first:HasTag("Direct"))
	assert(collectionService:HasTag(first, "Direct"))
	assertNameSetEqual(collectionService:GetTagged("Direct"), { "First" }, "direct instance tags")

	local directTags = {}
	for _, tag in ipairs(first:GetTags()) do
		directTags[tag] = true
	end

	assert(directTags.Enemy)
	assert(directTags.Direct)

	first:RemoveTag("Direct")
	assert(not first:HasTag("Direct"))
	assertEqual(#collectionService:GetTagged("Direct"), 0)

	collectionService:RemoveTag(first, "Enemy")
	assert(not collectionService:HasTag(first, "Enemy"))
	assertSequenceEqual(removed, { "First" }, "removed tags")

	second:Destroy()
	assertSequenceEqual(removed, { "First", "Second" }, "cleanup tags")
	assertEqual(#collectionService:GetTagged("Enemy"), 0)
end

function m.collectionServiceSignalsDataModelMembershipChanges()
	local env = createEnvironment({
		activePlayers = {},
	})
	local collectionService = env.game:GetService("CollectionService")
	local tagged = env.Instance.new("Folder")
	local added = 0
	local removed = 0

	tagged.Name = "TaggedFolder"
	tagged.Parent = env.globals.Workspace

	collectionService:GetInstanceAddedSignal("Stable"):Connect(function()
		added += 1
	end)
	collectionService:GetInstanceRemovedSignal("Stable"):Connect(function()
		removed += 1
	end)

	collectionService:AddTag(tagged, "Stable")
	tagged.Parent = nil
	assertEqual(#collectionService:GetTagged("Stable"), 0)
	assert(collectionService:HasTag(tagged, "Stable"))
	tagged.Parent = env.globals.ReplicatedStorage

	local taggedResults = collectionService:GetTagged("Stable")
	assertEqual(#taggedResults, 1)
	assertEqual(taggedResults[1], tagged)
	assert(collectionService:HasTag(tagged, "Stable"))
	assertEqual(added, 2)
	assertEqual(removed, 1)
end

function m.remoteEventRoutesAcrossServerAndClients()
	local env = createEnvironment({
		activePlayers = {
			{
				name = "Primary",
				userId = 10,
				localPlayer = true,
			},
		},
	})
	local remote = env.Instance.new("RemoteEvent")
	local defaultPlayer = env.globals.Players.LocalPlayer
	local secondClient = env:spawnClient({
		name = "Secondary",
		userId = 11,
	})
	local secondRemote = secondClient:bindRemote(remote)
	local serverEvents = {}
	local primaryMessages = {}
	local secondaryMessages = {}

	remote.Name = "PingEvent"

	remote.Parent = env.globals.ReplicatedStorage
	assertEqual(env.game:GetService("ReplicatedStorage"):FindFirstChild("PingEvent"), remote)
	assertEqual(secondClient.game:GetService("ReplicatedStorage"):FindFirstChild("PingEvent"), remote)

	remote.OnServerEvent:Connect(function(player, message)
		table.insert(serverEvents, `{player.Name}:{message}`)
	end)
	remote.OnClientEvent:Connect(function(message)
		table.insert(primaryMessages, message)
	end)
	secondRemote.OnClientEvent:Connect(function(message)
		table.insert(secondaryMessages, message)
	end)

	remote:FireServer("alpha")
	secondRemote:FireServer("beta")
	remote:FireClient(defaultPlayer, "direct")
	remote:FireAllClients("broadcast")

	assertSequenceEqual(serverEvents, { "Primary:alpha", "Secondary:beta" }, "server remote events")
	assertSequenceEqual(primaryMessages, { "direct", "broadcast" }, "primary client events")
	assertSequenceEqual(secondaryMessages, { "broadcast" }, "secondary client events")
	assertEqual(#env:inspectRemoteTraffic(), 5)

	local tupleArgs = {}

	remote.OnServerEvent:Connect(function(player, a, b, c)
		tupleArgs = { player.Name, a, b, c }
	end)

	remote:FireServer("multi", 2, true)

	assertSequenceEqual(tupleArgs, { "Primary", "multi", 2, true }, "server remote tuple args")

	local edgeRemote = env.Instance.new("RemoteEvent")
	edgeRemote.Name = "EdgeEvent"
	edgeRemote.Parent = env.globals.ReplicatedStorage

	local secondEdgeRemote = secondClient:bindRemote(edgeRemote)
	local serverSawFunctionArg = "unset"
	local clientSawHiddenInstance = "unset"

	edgeRemote.OnServerEvent:Connect(function(_, functionArg)
		serverSawFunctionArg = functionArg
	end)

	secondEdgeRemote.OnClientEvent:Connect(function(instanceArg)
		clientSawHiddenInstance = instanceArg
	end)

	secondEdgeRemote:FireServer(function() end)
	assertEqual(serverSawFunctionArg, nil)

	local serverOnlyFolder = env.Instance.new("Folder")
	serverOnlyFolder.Name = "ServerOnlyFolder"

	edgeRemote:FireClient(secondClient.LocalPlayer, serverOnlyFolder)
	assertEqual(clientSawHiddenInstance, nil)
end

function m.remoteFunctionSupportsInvokeServerAndClient()
	local env = createEnvironment({
		activePlayers = {
			{
				name = "Primary",
				userId = 21,
				localPlayer = true,
			},
		},
	})
	local remote = env.Instance.new("RemoteFunction")
	local secondClient = env:spawnClient({
		name = "Secondary",
		userId = 22,
	})
	local secondRemote = secondClient:bindRemote(remote)

	remote.Name = "PingFunction"
	remote.OnServerInvoke = function(player, number)
		return `{player.Name}:{number * 2}`
	end
	remote.OnClientInvoke = function(number)
		return number + 1
	end
	secondRemote.OnClientInvoke = function(number)
		return number + 5
	end

	assertEqual(remote:InvokeServer(6), "Primary:12")
	assertEqual(secondRemote:InvokeServer(4), "Secondary:8")
	assertEqual(remote:InvokeClient(env.globals.Players.LocalPlayer, 10), 11)
	assertEqual(remote:InvokeClient(secondClient.LocalPlayer, 10), 15)
end

function m.remoteFailuresProduceActionableErrors()
	local serverEnv = createEnvironment({
		activePlayers = {},
		isClient = false,
	})
	local serverRemoteEvent = serverEnv.Instance.new("RemoteEvent")
	local serverRemoteFunction = serverEnv.Instance.new("RemoteFunction")

	local fireServerOk, fireServerError = pcall(function()
		serverRemoteEvent:FireServer("payload")
	end)
	assert(not fireServerOk)
	assertContains(fireServerError, "without a LocalPlayer")

	local fireClientOk, fireClientError = pcall(function()
		serverRemoteEvent:FireClient(nil, "payload")
	end)
	assert(not fireClientOk)
	assertContains(fireClientError, "requires a player")

	local invokeServerOk, invokeServerError = pcall(function()
		serverRemoteFunction:InvokeServer(5)
	end)
	assert(not invokeServerOk)
	assertContains(invokeServerError, "without a LocalPlayer")

	local env = createEnvironment({
		activePlayers = {
			{
				name = "Primary",
				userId = 91,
				localPlayer = true,
			},
		},
	})
	local remoteFunction = env.Instance.new("RemoteFunction")
	local remoteEvent = env.Instance.new("RemoteEvent")
	local client = env:spawnClient({
		name = "Secondary",
		userId = 92,
	})
	local clientRemoteFunction = client:bindRemote(remoteFunction)
	local clientRemoteEvent = client:bindRemote(remoteEvent)

	local missingServerInvokeOk, missingServerInvokeError = pcall(function()
		remoteFunction:InvokeServer(10)
	end)
	assert(not missingServerInvokeOk)
	assertContains(missingServerInvokeError, "no OnServerInvoke handler")

	local missingClientInvokeOk, missingClientInvokeError = pcall(function()
		remoteFunction:InvokeClient(client.LocalPlayer, 10)
	end)
	assert(not missingClientInvokeOk)
	assertContains(missingClientInvokeError, "no OnClientInvoke handler")

	local unsupportedOverrideOk, unsupportedOverrideError = pcall(function()
		clientRemoteFunction.UnsupportedField = true
	end)
	assert(not unsupportedOverrideOk)
	assertContains(unsupportedOverrideError, "Unsupported client remote field override")

	local unsupportedEventOverrideOk, unsupportedEventOverrideError = pcall(function()
		clientRemoteEvent.UnsupportedField = true
	end)
	assert(not unsupportedEventOverrideOk)
	assertContains(unsupportedEventOverrideError, "Unsupported client remote field override")
end

function m.pairedClientsShareReplicatedTreeAndLocalPlayerContext()
	local env = createEnvironment({
		activePlayers = {
			{
				name = "Primary",
				userId = 31,
				localPlayer = true,
			},
		},
	})
	local sharedFolder = env.Instance.new("Folder")
	local secondClient = env:spawnClient({
		name = "Secondary",
		userId = 32,
	})

	sharedFolder.Name = "SharedFolder"
	sharedFolder.Parent = env.globals.ReplicatedStorage

	assertEqual(env.game:GetService("ReplicatedStorage").SharedFolder, sharedFolder)
	assertEqual(secondClient.game:GetService("ReplicatedStorage").SharedFolder, sharedFolder)
	assertEqual(env.globals.Players.LocalPlayer.Name, "Primary")
	assertEqual(secondClient.game:GetService("Players").LocalPlayer.Name, "Secondary")
	assert(secondClient.game:GetService("Players").LocalPlayer.PlayerScripts ~= nil)
	assert(secondClient.game:GetService("Players").LocalPlayer.Backpack ~= nil)
end

function m.playersLifecycleAndCharacterReplacementAreDeterministic()
	local env = createEnvironment({
		activePlayers = {},
	})
	local players = env.game:GetService("Players")
	local lifecycle = {}

	players.PlayerAdded:Connect(function(addedPlayer)
		table.insert(lifecycle, `added:{addedPlayer.Name}`)
	end)
	players.PlayerRemoving:Connect(function(removingPlayer)
		table.insert(lifecycle, `removing:{removingPlayer.Name}`)
	end)

	local player = env:addPlayer({
		name = "Builder",
		userId = 44,
	})

	player.CharacterAdded:Connect(function(character)
		table.insert(lifecycle, `character-added:{character.Name}`)
	end)
	player.CharacterRemoving:Connect(function(character)
		table.insert(lifecycle, `character-removing:{character.Name}`)
	end)

	local firstCharacter = env:replaceCharacter(player, {
		name = "BuilderCharacter",
	})
	local secondCharacter = env:replaceCharacter(player, {
		name = "BuilderCharacter2",
	})

	assertEqual(players:GetPlayers()[1], player)
	assertEqual(player.Backpack.Name, "Backpack")
	assertEqual(player.PlayerScripts.Name, "PlayerScripts")
	assertEqual(player.Character, secondCharacter)
	assertEqual(firstCharacter.Parent, nil)

	env:removePlayer(player)

	assertSequenceEqual(lifecycle, {
		"added:Builder",
		"character-added:BuilderCharacter",
		"character-removing:BuilderCharacter",
		"character-added:BuilderCharacter2",
		"removing:Builder",
		"character-removing:BuilderCharacter2",
	}, "player lifecycle")
	assertEqual(#players:GetPlayers(), 0)
end

function m.playersLookupAndLocalPlayerTransitions()
	local env = createEnvironment({
		activePlayers = {},
	})
	local first = env:addPlayer({
		name = "First",
		userId = 101,
		localPlayer = true,
	})
	local second = env:addPlayer({
		name = "Second",
		userId = 202,
	})

	assertEqual(env.game:GetService("Players"):GetPlayerByUserId(101), first)
	assertEqual(env.game:GetService("Players"):GetPlayerByUserId(202), second)
	assertEqual(env.globals.LocalPlayer, first)

	env:assignLocalPlayer(second)
	assertEqual(env.globals.LocalPlayer, second)
	assertEqual(env.game:GetService("Players").LocalPlayer, second)

	env:removePlayer(second)
	assert(env.globals.LocalPlayer == nil)
	assert(env.game:GetService("Players").LocalPlayer == nil)
	assertEqual(env.game:GetService("Players"):GetPlayerByUserId(202), nil)

	local serverEnv = createEnvironment({
		activePlayers = {},
		isClient = false,
	})
	assertEqual(#serverEnv.game:GetService("Players"):GetPlayers(), 0)
	assert(serverEnv.game:GetService("Players").LocalPlayer == nil)
	assert(serverEnv.globals.LocalPlayer == nil)
end

function m.schedulerSupportsSpawnDeferDelayWaitAndHeartbeat()
	local env = createEnvironment({
		activePlayers = {},
	})
	local runService = env.game:GetService("RunService")
	local order = {}

	runService.Heartbeat:Connect(function(deltaTime)
		table.insert(order, `heartbeat:{deltaTime}`)
	end)

	env.task.spawn(function()
		table.insert(order, "spawn-start")
		local elapsed = env.task.wait(2)
		table.insert(order, `spawn-end:{elapsed}`)
	end)
	env.task.defer(function()
		table.insert(order, "defer")
	end)
	env.task.delay(1, function()
		table.insert(order, "delay-1")
	end)

	assertEqual(#env:inspectTasks(), 3)
	env.scheduler:flush()
	assertSequenceEqual(order, { "spawn-start", "defer" }, "flush order")

	env.scheduler:advance(1)
	env.scheduler:advance(1)

	assertSequenceEqual(order, {
		"spawn-start",
		"defer",
		"heartbeat:1",
		"delay-1",
		"heartbeat:1",
		"spawn-end:2",
	}, "scheduled order")
	assertEqual(#env:inspectTasks(), 0)
end

function m.schedulerCancellationTimeoutRunAllAndErrors()
	local env = createEnvironment({
		activePlayers = {},
	})
	local folder = env.Instance.new("Folder")
	local cancelledRan = false
	local order = {}
	local handle = env.task.delay(1, function()
		cancelledRan = true
	end)

	env.task.cancel(handle)
	env.task.delay(0, function()
		table.insert(order, "zero")
	end)
	env.task.delay(-5, function()
		table.insert(order, "negative")
	end)
	env.scheduler:flush()
	assertSequenceEqual(order, { "zero", "negative" }, "zero and negative delay order")

	env.scheduler:advance(1)
	assert(not cancelledRan)

	local waited = "pending"
	env.task.spawn(function()
		waited = folder:WaitForChild("NeverArrives", 2)
	end)
	env.scheduler:flush()
	env.scheduler:advance(2)
	assert(waited == nil)

	local ranAll = 0
	env.task.delay(3, function()
		ranAll += 1
	end)
	env.scheduler:runAll()
	assertEqual(ranAll, 1)
	assertEqual(env.scheduler:now(), 6)

	local callbackErrorOk, callbackError = pcall(function()
		env.task.defer(function()
			error("callback boom")
		end)
		env.scheduler:flush()
	end)
	assert(not callbackErrorOk)
	assertContains(callbackError, "callback boom")

	local threadErrorOk, threadError = pcall(function()
		env.task.spawn(function()
			error("thread boom")
		end)
		env.scheduler:flush()
	end)
	assert(not threadErrorOk)
	assertContains(threadError, "thread boom")
end

function m.memoryStoreTeleportDiagnosticsAndResetWork()
	local env = createEnvironment({
		privateServerId = "ps-55",
		privateServerOwnerId = 55,
		activePlayers = {
			{
				name = "Traveler",
				userId = 55,
				localPlayer = true,
			},
		},
	})
	local memoryStoreService = env.game:GetService("MemoryStoreService")
	local teleportService = env.game:GetService("TeleportService")
	local map = memoryStoreService:GetSortedMap("Scores")
	local queue = memoryStoreService:GetQueue("Jobs")

	map:SetAsync("coins", 5, 1)
	assertEqual(map:GetAsync("coins"), 5)
	map:UpdateAsync("coins", function(value)
		return value + 10
	end, 1)
	assertEqual(map:GetAsync("coins"), 15)
	queue:AddAsync("a", 60)
	queue:AddAsync("b", 60)
	local queuedValues, queuedId = queue:ReadAsync(2, false, 0)
	assertSequenceEqual(queuedValues, { "a", "b" }, "queue order")
	assertEqual(type(queuedId), "string")
	queue:RemoveAsync(queuedId)

	env.scheduler:advance(1)
	assert(map:GetAsync("coins") == nil)

	local reservedServerAccessCode, reservedServerId = teleportService:ReserveServerAsync(1234)
	assertEqual(type(reservedServerAccessCode), "string")
	assertEqual(type(reservedServerId), "string")

	local teleportOptions = env.Instance.new("TeleportOptions")
	teleportOptions.ReservedServerAccessCode = reservedServerAccessCode
	teleportOptions:SetTeleportData({
		round = 2,
	})
	assertEqual(teleportOptions:GetTeleportData().round, 2)

	teleportService:TeleportAsync(1234, { env.globals.Players.LocalPlayer }, teleportOptions)

	assertEqual(env.game.PrivateServerId, "ps-55")
	assertEqual(env.game.PrivateServerOwnerId, 55)
	assertEqual(teleportService:GetLocalPlayerTeleportData().round, 2)
	assert(env:inspectTree():find("ReplicatedStorage") ~= nil)
	assert(#env:inspectSignals() > 0)
	assert(#env:inspectRemoteTraffic() > 0)

	env:reset({
		activePlayers = {},
	})

	local resetMap = env.game:GetService("MemoryStoreService"):GetSortedMap("Scores")
	assert(resetMap:GetAsync("coins") == nil)
	assertEqual(#env:inspectRemoteTraffic(), 0)
end

function m.memoryStoreAdditionalMapAndQueueBranches()
	local env = createEnvironment({
		activePlayers = {},
	})
	local memoryStoreService = env.game:GetService("MemoryStoreService")
	local map = memoryStoreService:GetSortedMap("Inventory")
	local queue = memoryStoreService:GetQueue("BuildQueue")

	map:SetAsync("b", 2, 60)
	map:SetAsync("a", 1, 60)

	local listed = map:GetRangeAsync(Enum.SortDirection.Ascending, 2)
	assertEqual(#listed, 2)
	assertEqual(listed[1].key, "a")
	assertEqual(listed[1].value, 1)
	assertEqual(listed[2].key, "b")
	assertEqual(listed[2].value, 2)

	local descending = map:GetRangeAsync(Enum.SortDirection.Descending, 2)

	assertEqual(#descending, 2)
	assertEqual(descending[1].key, "b")
	assertEqual(descending[1].value, 2)
	assertEqual(descending[2].key, "a")
	assertEqual(descending[2].value, 1)

	map:RemoveAsync("a")
	assert(map:GetAsync("a") == nil)
	local canceledValue = map:UpdateAsync("b", function()
		return nil
	end, 60)
	assert(canceledValue == nil)
	assertEqual(map:GetAsync("b"), 2)

	map:RemoveAsync("b")
	assert(map:GetAsync("b") == nil)

	map:SetAsync("ranked-a", "A", 60, 10)
	map:SetAsync("ranked-b", "B", 60, 1)

	local rankedValue, rankedSortKey = map:GetAsync("ranked-a")
	assertEqual(rankedValue, "A")
	assertEqual(rankedSortKey, 10)

	local updatedValue, updatedSortKey = map:UpdateAsync("ranked-a", function(oldValue, oldSortKey)
		assertEqual(oldValue, "A")
		assertEqual(oldSortKey, 10)
		return "A2", 20
	end, 60)

	assertEqual(updatedValue, "A2")
	assertEqual(updatedSortKey, 20)

	local rankedRange = map:GetRangeAsync(Enum.SortDirection.Ascending, 2)
	assertEqual(rankedRange[1].key, "ranked-b")
	assertEqual(rankedRange[1].value, "B")
	assertEqual(rankedRange[1].sortKey, 1)
	assertEqual(rankedRange[2].key, "ranked-a")
	assertEqual(rankedRange[2].value, "A2")
	assertEqual(rankedRange[2].sortKey, 20)

	map:RemoveAsync("ranked-a")
	map:RemoveAsync("ranked-b")

	queue:AddAsync("first", 60)
	queue:AddAsync("second", 60)
	queue:AddAsync("third", 60)
	assertEqual(queue:GetSizeAsync(), 3)
	local partialValues, partialId = queue:ReadAsync(2, false, 0)
	assertSequenceEqual(partialValues, { "first", "second" }, "partial queue read")
	assertEqual(type(partialId), "string")
	assertEqual(queue:GetSizeAsync(false), 3)
	assertEqual(queue:GetSizeAsync(true), 1)

	queue:RemoveAsync(partialId)
	assertEqual(queue:GetSizeAsync(), 1)

	local remainingValues, remainingId = queue:ReadAsync(5, false, 0)
	assertSequenceEqual(remainingValues, { "third" }, "oversized queue read")
	assertEqual(type(remainingId), "string")
	queue:RemoveAsync(remainingId)
	assertEqual(queue:GetSizeAsync(), 0)

	local priorityQueue = memoryStoreService:GetQueue("PriorityQueue")

	priorityQueue:AddAsync("low", 60, 1)
	priorityQueue:AddAsync("high", 60, 10)

	local priorityValues, priorityId = priorityQueue:ReadAsync(2, false, 0)

	assertSequenceEqual(priorityValues, { "high", "low" }, "priority queue order")
	assertEqual(type(priorityId), "string")
	priorityQueue:RemoveAsync(priorityId)

	local visibilityQueue = memoryStoreService:GetQueue("VisibilityTimeoutQueue", 2)

	visibilityQueue:AddAsync("visible-again", 60)

	local invisibleValues, invisibleId = visibilityQueue:ReadAsync(1, false, 0)
	assertSequenceEqual(invisibleValues, { "visible-again" }, "visibility timeout read")
	assertEqual(type(invisibleId), "string")
	assertEqual(visibilityQueue:GetSizeAsync(false), 1)
	assertEqual(visibilityQueue:GetSizeAsync(true), 0)

	env.scheduler:advance(2)

	assertEqual(visibilityQueue:GetSizeAsync(true), 1)

	visibilityQueue:RemoveAsync(invisibleId)
	assertEqual(visibilityQueue:GetSizeAsync(true), 1)

	local visibleAgainValues, visibleAgainId = visibilityQueue:ReadAsync(1, false, 0)
	assertSequenceEqual(visibleAgainValues, { "visible-again" }, "visibility timeout reread")
	assertEqual(type(visibleAgainId), "string")
	visibilityQueue:RemoveAsync(visibleAgainId)
	assertEqual(visibilityQueue:GetSizeAsync(), 0)

	local allOrNothingQueue = memoryStoreService:GetQueue("AllOrNothingQueue")

	allOrNothingQueue:AddAsync("only", 60)

	local allOrNothingValues = allOrNothingQueue:ReadAsync(2, true, 0)

	assertEqual(#allOrNothingValues, 0)
end

function m.environmentAvailabilityOverridesAndErrorsAreActionable()
	local env = createEnvironment({
		availableServices = {
			"RunService",
			"Workspace",
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

	local missingServiceOk, missingServiceError = pcall(function()
		env.game:GetService("Players")
	end)
	assert(not missingServiceOk)
	assert(missingServiceError:find("Available services") ~= nil)

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
		privateServerId = "before",
		privateServerOwnerId = 5,
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
		privateServerId = "after",
		privateServerOwnerId = 88,
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

function m.instanceEventSemanticsAndChildClearing()
	local env = createEnvironment({
		activePlayers = {},
	})
	local root = env.Instance.new("Folder")
	local child = env.Instance.new("Folder")
	local grandChild = env.Instance.new("Part")
	local ancestryParents = {}
	local destroyingCount = 0
	local changedProperties = {}
	local nameChanges = {}

	root.Name = "Root"
	child.Name = "Child"
	grandChild.Name = "GrandChild"

	child.AncestryChanged:Connect(function(_, parent)
		table.insert(ancestryParents, if parent ~= nil then parent.Name else "nil")
	end)
	child.Destroying:Connect(function()
		destroyingCount += 1
	end)
	grandChild.Destroying:Connect(function()
		destroyingCount += 1
	end)
	grandChild.Changed:Connect(function(propertyName)
		table.insert(changedProperties, propertyName)
	end)
	grandChild:GetPropertyChangedSignal("Name"):Connect(function()
		table.insert(nameChanges, grandChild.Name)
	end)

	child.Parent = root
	child.Parent = nil
	child.Parent = root
	grandChild.Parent = child

	grandChild.Name = "Renamed"
	grandChild.Transparency = 0.5
	grandChild.Transparency = 0.5

	assertSequenceEqual(ancestryParents, { "Root", "nil", "Root" }, "ancestry change order")
	assertSequenceEqual(nameChanges, { "Renamed" }, "name change signal")
	assertSequenceEqual(changedProperties, { "Name", "Transparency" }, "changed properties")

	root:ClearAllChildren()
	assertEqual(destroyingCount, 2)
	assertEqual(#root:GetChildren(), 0)
	assertEqual(#child:GetChildren(), 0)
end

function m.waitForChildImmediateTimeoutAndNoSchedulerErrors()
	local env = createEnvironment({
		activePlayers = {},
	})
	local folder = env.Instance.new("Folder")
	local existing = env.Instance.new("Folder")
	local waited = "pending"

	folder.Name = "Container"
	existing.Name = "Existing"
	existing.Parent = folder

	assertEqual(folder:WaitForChild("Existing", 5), existing)

	env.task.spawn(function()
		waited = folder:WaitForChild("Missing", 2)
	end)
	env.scheduler:flush()
	env.scheduler:advance(2)
	assert(waited == nil)

	local standalone = Instance.new("Folder")
	local waited2 = standalone:WaitForChild("Missing")
	assertEqual(waited2, nil)
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
	local env1, env2, env1Folder, env2Folder, baseEnvFolder = setupMultiEnvTest()

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
	local env1, env2, env1Folder, env2Folder, baseEnvFolder = setupMultiEnvTest()

	local function baseWorkspaceCheck()
		assert(env1 ~= env2)
		assert(env1Folder ~= env2Folder)
		assertEqual(env1Folder.Name, "Env1") --can access properties

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
	env2:install() --install without uninstall switches workspaces

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
	assertEqual(env.game:GetService("TeleportService"), game:GetService("TeleportService"))

	local runService = game:GetService("RunService")
	local playersService = game:GetService("Players")

	env:configure({
		isStudio = false,
		isClient = false,
		isServer = true,
		privateServerId = "after",
		privateServerOwnerId = 88,
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

	local function assertServiceNotCreatable(className)
		local ok, err = pcall(function()
			env.Instance.new(className)
		end)

		assert(not ok)
		assert(
			err:find("not creatable") ~= nil or err:find("cannot be created") ~= nil or err:find("Enabled types") ~= nil,
			string.format("%s should not be creatable; got %s", className, tostring(err))
		)
	end

	assertServiceNotCreatable("CollectionService")
	assertServiceNotCreatable("TeleportService")
	assertServiceNotCreatable("MemoryStoreService")
	assertServiceNotCreatable("RunService")
	assertServiceNotCreatable("DataModel")
	assertServiceNotCreatable("ReplicatedStorage")
	assertServiceNotCreatable("ServerScriptService")
	assertServiceNotCreatable("StarterPlayer")
	assertServiceNotCreatable("StarterPlayerScripts")
	assertServiceNotCreatable("PlayerScripts")

	assertEqual(env.game:GetService("CollectionService").ClassName, "CollectionService")
	assertEqual(env.game:GetService("TeleportService").ClassName, "TeleportService")
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
		privateServerId = "reserved-server-id",
		privateServerOwnerId = 0,
		activePlayers = {},
	})

	assert(reserved.game.PrivateServerId ~= "")
	assertEqual(reserved.game.PrivateServerOwnerId, 0)

	local privateServer = createEnvironment({
		privateServerId = "private-server-id",
		privateServerOwnerId = 12345,
		activePlayers = {},
	})

	assert(privateServer.game.PrivateServerId ~= "")
	assertEqual(privateServer.game.PrivateServerOwnerId, 12345)
end

function m.waitForChildToplevel()
	local items = Instance.new("Folder", ReplicatedStorage)
	items.Name = "Items"

	local waited = ReplicatedStorage:WaitForChild("Items")
	assertEqual(waited, items)

	local waited2 = items:WaitForChild("Parts")
	assertEqual(waited2, nil)

	local parts = Instance.new("Folder", items)
	parts.Name = "Parts"

	assertEqual(waited2, nil)

	local waited3 = items:WaitForChild("Parts")
	assertEqual(waited3, parts)
end

function m.waitForChildToplevelMissingServiceChildReturnsNil()
	local waited = ReplicatedStorage:WaitForChild("Items")

	assertEqual(waited, nil)
end

return m
