local TestHelpers = require("@test/test_helpers")

local assertContains = TestHelpers.assertContains
local assertEqual = TestHelpers.assertEqual
local assertSequenceEqual = TestHelpers.assertSequenceEqual

local m = {}

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
		datamodel = {
			PrivateServerId = "ps-55",
			PrivateServerOwnerId = 55,
		},
		activePlayers = {
			{
				name = "Traveler",
				userId = 55,
				localPlayer = true,
			},
		},
	})
	local memoryStoreService = env.game:GetService("MemoryStoreService")
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

	assertEqual(env.game.PrivateServerId, "ps-55")
	assertEqual(env.game.PrivateServerOwnerId, 55)
	assertEqual(env.game:GetService("TeleportService"), nil)
	assert(env:inspectTree():find("ReplicatedStorage") ~= nil)
	assert(#env:inspectSignals() > 0)
	assertEqual(#env:inspectRemoteTraffic(), 0)

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

return m
