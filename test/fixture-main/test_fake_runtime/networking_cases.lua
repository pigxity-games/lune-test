local TestHelpers = require("@test/test_helpers")

local assertEqual = TestHelpers.assertEqual
local assertSequenceEqual = TestHelpers.assertSequenceEqual

local m = {}

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
	local secondPlayer = env:addPlayer({
		name = "Secondary",
		userId = 11,
	})
	local serverEvents = {}
	local primaryMessages = {}
	local secondaryMessages = {}

	remote.Name = "PingEvent"

	remote.Parent = env.globals.ReplicatedStorage
	assertEqual(env.game:GetService("ReplicatedStorage"):FindFirstChild("PingEvent"), remote)

	remote.OnServerEvent:Connect(function(player, message)
		table.insert(serverEvents, `{player.Name}:{message}`)
	end)
	remote.OnClientEvent:Connect(function(message)
		table.insert(primaryMessages, message)
	end)
	remote.OnClientEvent:ConnectPlayer(secondPlayer, function(message)
		table.insert(secondaryMessages, message)
	end)

	remote:FireServer("alpha")
	env:assignLocalPlayer(secondPlayer)
	remote:FireServer("beta")
	env:assignLocalPlayer(defaultPlayer)
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

	local serverSawFunctionArg = "unset"
	local clientSawHiddenInstance = "unset"

	edgeRemote.OnServerEvent:Connect(function(_, functionArg)
		serverSawFunctionArg = functionArg
	end)

	edgeRemote.OnClientEvent:ConnectPlayer(secondPlayer, function(instanceArg)
		clientSawHiddenInstance = instanceArg
	end)

	env:assignLocalPlayer(secondPlayer)
	edgeRemote:FireServer(function() end)
	env:assignLocalPlayer(defaultPlayer)
	assertEqual(serverSawFunctionArg, nil)

	local serverOnlyFolder = env.Instance.new("Folder")
	serverOnlyFolder.Name = "ServerOnlyFolder"

	edgeRemote:FireClient(secondPlayer, serverOnlyFolder)
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
	local defaultPlayer = env.globals.Players.LocalPlayer
	local secondPlayer = env:addPlayer({
		name = "Secondary",
		userId = 22,
	})

	remote.Name = "PingFunction"
	remote.OnServerInvoke = function(player, number)
		return `{player.Name}:{number * 2}`
	end
	remote.OnClientInvoke = function(number)
		return number + 1
	end

	assertEqual(remote:InvokeServer(6), "Primary:12")
	env:assignLocalPlayer(secondPlayer)
	assertEqual(remote:InvokeServer(4), "Secondary:8")
	env:assignLocalPlayer(defaultPlayer)
	assertEqual(remote:InvokeClient(defaultPlayer, 10), 11)
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
	assert(tostring(fireServerError):find("without a LocalPlayer", 1, true) ~= nil)

	local fireClientOk, fireClientError = pcall(function()
		serverRemoteEvent:FireClient(nil, "payload")
	end)
	assert(not fireClientOk)
	assert(tostring(fireClientError):find("requires a player", 1, true) ~= nil)

	local invokeServerOk, invokeServerError = pcall(function()
		serverRemoteFunction:InvokeServer(5)
	end)
	assert(not invokeServerOk)
	assert(tostring(invokeServerError):find("without a LocalPlayer", 1, true) ~= nil)

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
	local secondaryPlayer = env:addPlayer({
		name = "Secondary",
		userId = 92,
	})

	local missingServerInvokeOk, missingServerInvokeError = pcall(function()
		remoteFunction:InvokeServer(10)
	end)
	assert(not missingServerInvokeOk)
	assert(tostring(missingServerInvokeError):find("no OnServerInvoke handler", 1, true) ~= nil)

	local missingClientInvokeOk, missingClientInvokeError = pcall(function()
		remoteFunction:InvokeClient(secondaryPlayer, 10)
	end)
	assert(not missingClientInvokeOk)
	assert(tostring(missingClientInvokeError):find("no OnClientInvoke handler", 1, true) ~= nil)
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
	local secondPlayer = env:addPlayer({
		name = "Secondary",
		userId = 32,
	})

	sharedFolder.Name = "SharedFolder"
	sharedFolder.Parent = env.globals.ReplicatedStorage

	assertEqual(env.game:GetService("ReplicatedStorage").SharedFolder, sharedFolder)
	assertEqual(env.globals.Players.LocalPlayer.Name, "Primary")
	assertEqual(secondPlayer.PlayerScripts.Name, "PlayerScripts")
	assertEqual(secondPlayer.Backpack.Name, "Backpack")

	env:assignLocalPlayer(secondPlayer)

	assertEqual(env.game:GetService("Players").LocalPlayer.Name, "Secondary")
	assertEqual(env.globals.LocalPlayer, secondPlayer)
	assertEqual(env.game:GetService("ReplicatedStorage").SharedFolder, sharedFolder)
end

return m
