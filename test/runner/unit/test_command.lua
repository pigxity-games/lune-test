local command = require("@src/runner/command")
local process = require("@lune/process")

local m = {}

function m.usesDefaultManifestWhenNoSelectionIsPassed()
	local selections = command.buildSelections({
		manifestPath = nil,
		workspaceName = nil,
		selections = {},
	})

	assert(#selections == 1)
	assert(selections[1].kind == "manifest")
end

function m.resolvesClosestManifestForScripts()
	local selections = command.buildSelections({
		manifestPath = nil,
		workspaceName = nil,
		selections = { "test/fixture-main/scripts/uses_modules.lua" },
	})

	assert(#selections == 1)
	assert(selections[1].kind == "script")
	assert(selections[1].manifestPath:match("test/fixture%-main/manifest%.lua$") ~= nil)
end

function m.runsScriptsWithWorkspaceFlag()
	local hubResults = command.run({
		"--workspace",
		"hub",
		"test/multi-workspace/scripts/hub_script.lua",
	})
	local gameResults = command.run({
		"--workspace",
		"game",
		"test/multi-workspace/scripts/game_script.lua",
	})

	assert(hubResults.success)
	assert(gameResults.success)
end

function m.runsMixedScriptsAndSuites()
	local results = command.run({
		"test_runner_core,test/multi-workspace/scripts/game_script.lua",
		"--workspace",
		"game",
	})

	assert(results.success)
	assert(results.total == 11)
end

function m.runsManualSelectionsForDiscoveredSuitesByFilename()
	local results = command.run({
		"--manifest",
		"test/manual-suite-selection/manifest.lua",
		"config_unit,mine_unit",
	})

	assert(results.success)
	assert(results.total == 2)
end

function m.runsWorkspaceLocalDiscoveredSuitesFromManifest()
	local results = command.run({
		"--manifest",
		"test/workspace-test-locations/manifest.lua",
	})

	assert(results.success)
	assert(results.matchedSuiteCount == 2)
	assert(results.total == 2)
end

function m.suppressesReporterOutputForScriptOnlyRuns()
	local scriptOnly = process.exec("lune", {
		"run",
		"src/main.lua",
		"test/multi-workspace/scripts/game_script.lua",
	})
	local mixed = process.exec("lune", {
		"run",
		"src/main.lua",
		"test_runner_core,test/multi-workspace/scripts/game_script.lua",
		"--workspace",
		"game",
	})

	assert(scriptOnly.ok and scriptOnly.code == 0)
	assert(not scriptOnly.stdout:find("%[TEST%]:", 1, false))
	assert(not scriptOnly.stdout:find("%[PASS%]:", 1, false))
	assert(not scriptOnly.stdout:find("TEST RESULTS:", 1, true))
	assert(scriptOnly.stdout:find("Hello World", 1, true) ~= nil)

	assert(mixed.ok and mixed.code == 0)
	assert(mixed.stdout:find("%[TEST%]:", 1, false) ~= nil)
	assert(mixed.stdout:find("%[PASS%]:", 1, false) ~= nil)
	assert(mixed.stdout:find("TEST RESULTS:", 1, true) ~= nil)
end

return m
