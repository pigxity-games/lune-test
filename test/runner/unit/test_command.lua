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

function m.errorsWhenDashAHasNoScriptSelections()
	local noSelectionsOk, noSelectionsError = pcall(function()
		command.buildSelections({
			manifestPath = nil,
			workspaceName = nil,
			selections = {},
			scriptArgs = { "1", "testString", "123" },
		})
	end)
	local suiteOnlyOk, suiteOnlyError = pcall(function()
		command.buildSelections({
			manifestPath = nil,
			workspaceName = nil,
			selections = { "test_runner_core" },
			scriptArgs = { "1", "testString", "123" },
		})
	end)

	assert(not noSelectionsOk)
	assert(tostring(noSelectionsError):find("%-a requires at least one script selection", 1) ~= nil)
	assert(not suiteOnlyOk)
	assert(tostring(suiteOnlyError):find("%-a requires at least one script selection", 1) ~= nil)
end

function m.scriptOnlyFailuresPrintErrorsAndExitNonZero()
	local result = process.exec("lune", {
		"run",
		"src/main.lua",
		"test/runner/fixtures/invalid_require/typo_alias.lua",
	})

	assert(not result.ok)
	assert(result.code == 1)
	assert(result.stdout:find("Unable to resolve module path", 1, true) ~= nil)
	assert(result.stdout:find("@test/test_helperss", 1, true) ~= nil)
end

function m.invalidSuiteModuleErrorsBeforeRunningEveryCase()
	local result = process.exec("lune", {
		"run",
		"src/main.lua",
		"--manifest",
		"test/runner/fixtures/invalid_suite_module/manifest.lua",
	})

	assert(not result.ok)
	assert(result.code == 1)
	assert(result.stdout:find("%[TEST%]: invalid_suite_module", 1, false) ~= nil, result.stdout)
	assert(not result.stdout:find("%[FAIL%]:", 1, false), result.stdout)
	assert(not result.stdout:find("TEST RESULTS:", 1, true), result.stdout)
	assert(result.stdout:find("syntax_error_suite", 1, true) ~= nil, result.stdout)
end

function m.invalidManifestSyntaxErrorsBeforeAnySuiteRuns()
	local result = process.exec("lune", {
		"run",
		"src/main.lua",
		"--manifest",
		"test/runner/fixtures/invalid_manifest_syntax/manifest.lua",
	})

	assert(not result.ok)
	assert(result.code == 1)
	assert(not result.stdout:find("%[TEST%]:", 1, false), result.stdout)
	assert(not result.stdout:find("%[FAIL%]:", 1, false), result.stdout)
	assert(not result.stdout:find("TEST RESULTS:", 1, true), result.stdout)
	assert(result.stdout:find("manifest.lua", 1, true) ~= nil, result.stdout)
	assert(result.stdout:find("syntax error", 1, true) ~= nil, result.stdout)
end

function m.invalidManifestTopLevelErrorsBeforeAnySuiteRuns()
	local result = process.exec("lune", {
		"run",
		"src/main.lua",
		"--manifest",
		"test/runner/fixtures/invalid_manifest_top_level/manifest.lua",
	})

	assert(not result.ok)
	assert(result.code == 1)
	assert(not result.stdout:find("%[TEST%]:", 1, false), result.stdout)
	assert(not result.stdout:find("%[FAIL%]:", 1, false), result.stdout)
	assert(not result.stdout:find("TEST RESULTS:", 1, true), result.stdout)
	assert(result.stdout:find("manifest exploded at top level", 1, true) ~= nil, result.stdout)
end

function m.printsWarningsForFallbackAliasResolution()
	local repoFallback = process.exec("lune", {
		"run",
		"src/main.lua",
		"test/runner/fixtures/invalid_require/fallback_repo_alias.lua",
	})
	local mountFallback = process.exec("lune", {
		"run",
		"src/main.lua",
		"test/fixture-main/scripts/fallback_mount_alias.lua",
	})

	assert(repoFallback.ok and repoFallback.code == 0)
	assert(
		repoFallback.stdout:find('WARNING: Falling back to repo%-relative alias resolution', 1) ~= nil,
		repoFallback.stdout
	)
	assert(repoFallback.stdout:find('@fallback_repo/module', 1) ~= nil, repoFallback.stdout)

	assert(mountFallback.ok and mountFallback.code == 0)
	assert(
		mountFallback.stdout:find('WARNING: Falling back to mounted%-root alias resolution', 1) ~= nil,
		mountFallback.stdout
	)
	assert(mountFallback.stdout:find('@legacy/shared/StatefulModule', 1) ~= nil, mountFallback.stdout)
end

return m
