local TestHelpers = require("@test/test_helpers")

local assertEqual = TestHelpers.assertEqual
local assertSequenceEqual = TestHelpers.assertSequenceEqual

local m = {}

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

function m.addPlayerCreateCharacterSpawnsCharacterModel()
	local env = createEnvironment({
		activePlayers = {},
	})
	local player = env:addPlayer({
		name = "Builder",
		userId = 404,
		createCharacter = true,
	})

	assertEqual(player.ClassName, "Player")
	assert(player.Character ~= nil)
	assertEqual(player.Character.ClassName, "Model")
	assertEqual(player.Character.Name, "Builder")
	assertEqual(player.Character.Parent, env.game:GetService("Workspace"))
end

function m.addPlayerRunHooksFalseSkipsPlayerAndCharacterSignals()
	local env = createEnvironment({
		activePlayers = {},
	})
	local players = env.game:GetService("Players")
	local playerAddedCount = 0
	local lastAddedPlayer = nil
	local characterAddedCount = 0
	local player = env.Instance.new("Player")

	players.PlayerAdded:Connect(function(addedPlayer)
		playerAddedCount += 1
		lastAddedPlayer = addedPlayer
	end)

	player.CharacterAdded:Connect(function()
		characterAddedCount += 1
	end)

	local returnedPlayer = env:addPlayer({
		instance = player,
		name = "SilentBuilder",
		userId = 405,
		createCharacter = true,
		runHooks = false,
	})

	assertEqual(returnedPlayer, player)
	assertEqual(playerAddedCount, 0)
	assertEqual(lastAddedPlayer, nil)
	assertEqual(characterAddedCount, 0)
	assertEqual(players:GetPlayerByUserId(405), player)
	assert(player.Character ~= nil)
	assertEqual(player.Character.Name, "SilentBuilder")
	assertEqual(player.Character.Parent, env.game:GetService("Workspace"))
end

return m
