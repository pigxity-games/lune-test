local manifestRunner = require("@src/runner/manifest")
local runner = require("@src/runner/run")
local paths = require("@src/runner/paths")

local m = {}

local fixtureMainManifest = manifestRunner.loadManifest("test/fixture-main/manifest.lua")
local fixtureMainMounts = manifestRunner.getMountsForWorkspace(fixtureMainManifest, nil)

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
	local results = runner.runSelections({
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/stateful_first.lua"),
			displayName = "stateful_first",
			mounts = fixtureMainMounts,
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/stateful_second.lua"),
			displayName = "stateful_second",
			mounts = fixtureMainMounts,
		},
	})

	assert(results.success)
	assert(results.total == 2)
end

function m.runsMixedSuiteAndScriptSelections()
	local expectedTotal = countSuiteCases(fixtureMainManifest, "test_module_requires") + 1
	local results = runner.runSelections({
		{
			kind = "suite",
			manifest = fixtureMainManifest,
			suiteName = "test_module_requires",
		},
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/fixture-main/scripts/uses_modules.lua"),
			displayName = "uses_modules",
			mounts = fixtureMainMounts,
		},
	})

	assert(results.success)
	assert(results.total == expectedTotal)
end

function m.topLevelMissingChildReturnsNilDuringScriptLoad()
	local results = runner.runSelections({
		{
			kind = "script",
			filePath = paths.sourceFilePathWithoutExtension("test/runner/fixtures/top_level_yield/yielding_script.lua"),
			displayName = "yielding_script",
			mounts = fixtureMainMounts,
		},
	})

	assert(results.success)
	assert(results.total == 1)
end

function m.topLevelMissingChildReturnsNilDuringCaseExecution()
	local results = runner.runSelections({
		{
			kind = "suite",
			manifest = {
				tests = {
					yielding_case_suite = {
						module = "test/runner/fixtures/top_level_yield/yielding_case",
						cases = {
							waitsForMissingGenerated = {},
						},
						mounts = fixtureMainMounts,
					},
				},
			},
			suiteName = "yielding_case_suite",
		},
	})

	assert(results.success)
	assert(results.total == 1)
end

return m
