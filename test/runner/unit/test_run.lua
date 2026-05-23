local manifestRunner = require("@src/runner/manifest")
local runner = require("@src/runner/run")
local paths = require("@src/runner/paths")

local m = {}

function m.runsScriptSelectionsInSeparateSandboxes()
	local manifest = manifestRunner.loadManifest("test/fixture-main/manifest.lua")
	local mounts = manifestRunner.getMountsForWorkspace(manifest, nil)
	local results = runner.runSelections({
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/stateful_first.lua"),
			displayName = "stateful_first",
			mounts = mounts,
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/stateful_second.lua"),
			displayName = "stateful_second",
			mounts = mounts,
		},
	})

	assert(results.success)
	assert(results.total == 2)
end

function m.runsMixedSuiteAndScriptSelections()
	local manifest = manifestRunner.loadManifest("test/fixture-main/manifest.lua")
	local mounts = manifestRunner.getMountsForWorkspace(manifest, nil)
	local results = runner.runSelections({
		{
			kind = "suite",
			manifest = manifest,
			suiteName = "test_module_requires",
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/uses_modules.lua"),
			displayName = "uses_modules",
			mounts = mounts,
		},
	})

	assert(results.success)
	assert(results.total == 3)
end

return m
