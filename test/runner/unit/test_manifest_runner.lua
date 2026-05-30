local manifestRunner = require("@src/runner/manifest")
local runner = require("@src/runner/run")

local m = {}

function m.findsNearestManifestForScript()
	local manifestPath = manifestRunner.findNearestManifest("test/fixture-main/scripts/uses_modules.lua")

	assert(manifestPath ~= nil)
	assert(manifestPath:match("test/fixture%-main/manifest%.lua$") ~= nil)
end

function m.returnsWorkspaceMounts()
	local manifest = manifestRunner.loadManifest("test/multi-workspace/manifest.lua")
	local mounts = manifestRunner.getMountsForWorkspace(manifest, "hub")

	assert(#mounts >= 2)
	assert(mounts[1].mountPath ~= nil)
end

function m.returnsManifestMountsByDefault()
	local manifest = manifestRunner.loadManifest("test/fixture-main/manifest.lua")
	local mounts = manifestRunner.getMountsForWorkspace(manifest, nil)

	assert(#mounts == 3)
end

function m.infersWorkspaceForScript()
	local manifest = manifestRunner.loadManifest("test/multi-workspace/manifest.lua")
	local mounts = manifestRunner.getMountsForScript(manifest, "test/multi-workspace/scripts/game_script.lua", nil)
	local foundGameMount = false

	for _, mountData in ipairs(mounts) do
		if mountData.mountPath == "ServerScriptService/Game" then
			foundGameMount = true
			break
		end
	end

	assert(#mounts >= 3)
	assert(foundGameMount)
end

function m.normalizesNestedPlayerScriptsRojoMounts()
	local manifest = manifestRunner.loadManifest("test/runner/fixtures/player_scripts_nested_rojo/manifest.lua")
	local foundNestedPlayerScriptsMount = false

	for _, mountData in ipairs(manifest.mounts) do
		if mountData.mountPath == "PlayerScripts/Common" then
			foundNestedPlayerScriptsMount = true
			break
		end
	end

	assert(foundNestedPlayerScriptsMount)
end

function m.discoversWorkspaceLocalTestLocations()
	local manifest = manifestRunner.loadManifest("test/workspace-test-locations/manifest.lua")

	assert(manifest.tests["game/unit/game_workspace_unit"] ~= nil)
	assert(manifest.tests["hub/unit/hub_workspace_unit"] ~= nil)

	local results = runner.runSelections({
		{
			kind = "suite",
			manifest = manifest,
			suiteName = "game/unit/game_workspace_unit",
		},
		{
			kind = "suite",
			manifest = manifest,
			suiteName = "hub/unit/hub_workspace_unit",
		},
	})

	assert(results.success)
	assert(results.total == 2)
end

function m.discoveredSuitesSupportRelativeAndSelfRequires()
	local manifest = manifestRunner.loadManifest("test/runner/fixtures/discovered_relative_require/manifest.lua")
	local results = runner.runSelections({
		{
			kind = "manifest",
			manifest = manifest,
		},
	})

	assert(results.success)
	assert(results.total == 3)
end

return m
