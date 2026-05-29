local TestHelpers = require("@test/test_helpers")

local assertEqual = TestHelpers.assertEqual
local assertNameSetEqual = TestHelpers.assertNameSetEqual
local assertSequenceEqual = TestHelpers.assertSequenceEqual

local m = {}

function m.signalDisconnectAllAndDisconnectDuringFire()
	local signal = RBXScriptSignal.new("ComplexSignal")
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

function m.signalConnectPlayerTargetsSpecificPlayers()
	local env = createEnvironment({
		activePlayers = {},
	})
	local firstPlayer = env:addPlayer({
		name = "Player1",
		userId = 701,
	})
	local secondPlayer = env:addPlayer({
		name = "Player2",
		userId = 702,
	})
	local signal = RBXScriptSignal.new("PlayerSignal")
	local firstTotal = 0
	local secondTotal = 0

	signal:ConnectPlayer(firstPlayer, function(value)
		firstTotal += value
	end)
	signal:ConnectPlayer(secondPlayer, function(value)
		secondTotal += value
	end)

	signal:FireForPlayer(firstPlayer, 1)
	signal:FireForPlayer(secondPlayer, 3)

	assertEqual(firstTotal, 1)
	assertEqual(secondTotal, 3)
	assertEqual(signal:GetConnectionCount(), 2)
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

return m
