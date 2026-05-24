local manifestRunner = require("@src/runner/manifest")
local runner = require("@src/runner/run")
local paths = require("@src/runner/paths")

local m = {}

local function countSuiteCases(manifest, suiteName)
	local suite = manifest.tests[suiteName]
	assert(suite ~= nil, `missing suite: {suiteName}`)

	local total = 0

	for _ in pairs(suite.cases) do
		total += 1
	end

	return total
end

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
	local expectedTotal = countSuiteCases(manifest, "test_module_requires") + 1
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
	assert(results.total == expectedTotal)
end

return m
