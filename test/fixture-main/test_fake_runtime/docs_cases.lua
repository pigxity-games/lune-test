local m = {}

function m.environmentDocsFieldsExample()
	local env = getEnvironment()

	local part = Instance.new("Part", workspace)
	part.Name = "Part"
	assert(part == env.game:GetService("Workspace").Part)
end

function m.environmentDocsConfigureExample()
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
		globals = {
			myGlobal = "Test",
		},
	})

	assert(game:GetService("ReplicatedStorage") ~= nil)
	assert(game:GetService("RunService") == nil)

	game:GetService("MyCustomService").increment()
	assert(counter == 1)

	assert(myGlobal == "Test")
end

function m.environmentDocsInstallExample()
	local env = getEnvironment()

	env.globals.myGlobal = "Hello"

	assert(env.globals.myGlobal == "Hello")
	assert(myGlobal == nil)

	env:install()
	assert(myGlobal == "Hello")

	local env2 = createEnvironment({
		globals = {
			myGlobal = "Test",
		},
	})

	env2:install()
	assert(myGlobal == "Test")

	env2:uninstall()
	assert(myGlobal == "Hello")
end

function m.schedulerDocsDelayExample()
	local env = getEnvironment()

	local done = false

	task.delay(1, function()
		done = true
	end)

	env.scheduler:advance(0.5)
	assert(done == false)

	env.scheduler:advance(0.5)
	assert(done == true)
end

function m.schedulerDocsTaskApiExample()
	local order = {}

	task.defer(function()
		table.insert(order, "defer")
	end)

	task.spawn(function()
		table.insert(order, "spawn")
	end)

	getEnvironment().scheduler:flush()

	assert(#order == 2)
end

function m.schedulerDocsWaitingExample()
	local env = getEnvironment()
	local finished = false

	task.spawn(function()
		task.wait(2)
		finished = true
	end)

	env.scheduler:flush() --starts the thread

	env.scheduler:advance(1)
	assert(finished == false)

	env.scheduler:advance(1)
	assert(finished == true)
end

function m.schedulerDocsWaitForChildExample()
	local env = getEnvironment()
	local folder = Instance.new("Folder", workspace)
	local found

	task.spawn(function()
		found = folder:WaitForChild("Child", 1)
	end)

	task.defer(function()
		local child = Instance.new("Folder", folder)
		child.Name = "Child"
	end)

	env.scheduler:runAll()
	assert(found == folder.Child)
end

function m.servicesDocsStableServiceExample()
	local replicatedStorage = game:GetService("ReplicatedStorage")
	assert(replicatedStorage == game:GetService("ReplicatedStorage"))
end

function m.servicesDocsCustomServiceExample()
	local env = createEnvironment({
		availableServices = {
			ReplicatedStorage = true,
			MyCustomService = true,
		},
		serviceOverrides = {
			MyCustomService = {
				Ping = function()
					return "pong"
				end,
			},
		},
	})

	env:install()
	assert(game:GetService("MyCustomService"):Ping() == "pong")
	env:uninstall()
end

function m.servicesDocsInstanceServiceExample()
	local shared = game:GetService("ReplicatedStorage")
	local module = require(shared.SomeModule)

	assert(type(module) == "table")
end

function m.servicesDocsRunServiceExample()
	local env = getEnvironment()
	local runService = game:GetService("RunService")

	local dt
	runService.Heartbeat:Connect(function(deltaTime)
		dt = deltaTime
	end)

	env.scheduler:advance(0.25)
	assert(dt == 0.25)
end

function m.servicesDocsPlayersExample()
	local env = getEnvironment()
	local players = game:GetService("Players")

	local player = env:addPlayer({
		name = "TestPlayer",
		userId = 42,
		createCharacter = true,
	})

	assert(players:GetPlayerByUserId(42) == player)
	assert(player.Character ~= nil)
end

function m.servicesDocsCollectionServiceExample()
	local collectionService = game:GetService("CollectionService")
	local part = Instance.new("Part", workspace)

	collectionService:AddTag(part, "Interactable")
	assert(part:HasTag("Interactable"))
	assert(collectionService:GetTagged("Interactable")[1] == part)
end

function m.servicesDocsMemoryStoreMapExample()
	local map = game:GetService("MemoryStoreService"):GetSortedMap("scores")

	map:SetAsync("player-a", 10, nil, 10)
	map:SetAsync("player-b", 25, nil, 25)

	local top = map:GetRangeAsync(Enum.SortDirection.Descending, 1)
	assert(top[1].key == "player-b")
end

function m.servicesDocsMemoryStoreQueueExample()
	local queue = game:GetService("MemoryStoreService"):GetQueue("jobs")

	queue:AddAsync("first")

	local values, reservationId = queue:ReadAsync(1)
	assert(values[1] == "first")

	queue:RemoveAsync(reservationId)
	assert(queue:GetSizeAsync() == 0)
end

function m.networkingDocsRemoteEventClientToServerExample()
	local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
	remote.Name = "Ping"

	local received
	remote.OnServerEvent:Connect(function(player, value)
		received = { player = player, value = value }
	end)

	remote:FireServer("hello")

	assert(received.player == game:GetService("Players").LocalPlayer)
	assert(received.value == "hello")
end

function m.networkingDocsRemoteFunctionClientToServerExample()
	local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
	remote.Name = "Add"

	remote.OnServerInvoke = function(player, a, b)
		return a + b
	end

	assert(remote:InvokeServer(2, 3) == 5)
end

function m.networkingDocsSinglePlayerServerToClientExample()
	local env = getEnvironment()
	local player = env:addPlayer({
		name = "Player",
		localPlayer = true,
	})

	local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
	local n = 0

	remote.OnClientEvent:Connect(function(player, value)
		n += 1
	end)

	remote:FireClient(player)
	assert(n == 1)
end

function m.networkingDocsMultiPlayerServerToClientExample()
	local env = getEnvironment()
	local player1 = env:addPlayer({
		name = "Player1",
	})

	local player2 = env:addPlayer({
		name = "Player2",
	})

	local player1Count = 0
	local player2Count = 0

	local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))

	remote.OnClientEvent:ConnectPlayer(player1, function(num)
		player1Count += num
	end)
	remote.OnClientEvent:ConnectPlayer(player2, function(num)
		player2Count += num
	end)

	remote:FireClient(player1, 1)
	remote:FireClient(player2, 3)

	assert(player1Count == 1)
	assert(player2Count == 3)
end

function m.networkingDocsDiagnosticsExample()
	local env = getEnvironment()
	local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
	remote.Name = "LogMe"

	remote:FireServer("payload")

	local traffic = env:inspectRemoteTraffic()
	assert(traffic[#traffic].kind == "FireServer")
	assert(traffic[#traffic].remoteName == "LogMe")
end

function m.datatypesDocsSupportedInstanceClassesExample()
	local folder = Instance.new("Folder", workspace)
	folder.Name = "Things"

	local part = Instance.new("Part", folder)
	part.Name = "Block"

	assert(workspace.Things.Block == part)
	assert(part:GetFullName() == "game.Workspace.Things.Block")
end

function m.datatypesDocsInstanceApiExample()
	local value = Instance.new("NumberValue")
	local changed

	value.Changed:Connect(function(newValue)
		changed = newValue
	end)

	value.Value = 10
	assert(changed == 10)
end

function m.datatypesDocsRbxScriptSignalExample()
	local signal = RBXScriptSignal.new("Example")
	local count = 0

	local connection = signal:Connect(function()
		count += 1
	end)

	signal:Fire()
	connection:Disconnect()
	signal:Fire()

	assert(count == 1)
end

function m.datatypesDocsVectorExample()
	local a = Vector3.new(1, 2, 3)
	local b = Vector3.new(4, 5, 6)

	assert(a + b == Vector3.new(5, 7, 9))
	assert(a:Dot(b) == 32)
end

function m.datatypesDocsColor3Example()
	local color = Color3.fromRGB(255, 0, 128)
	assert(color:ToHex() == "FF0080")
end

function m.datatypesDocsRandomExample()
	local random = Random.new(123)
	local clone = random:Clone()

	assert(random:NextInteger(1, 10) == clone:NextInteger(1, 10))
end

return m
