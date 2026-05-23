local cli = require("@src/runner/cli")

local m = {}

function m.parsesManifestWorkspaceAndSelections()
	local options = cli.parseArgs({
		"--manifest",
		"test/multi-workspace/manifest.lua",
		"-w",
		"hub",
		"hub_tests,test/fixture-main/scripts/uses_modules.lua",
	})

	assert(options.manifestPath == "test/multi-workspace/manifest.lua")
	assert(options.workspaceName == "hub")
	assert(#options.selections == 2)
	assert(options.selections[1] == "hub_tests")
	assert(options.selections[2] == "test/fixture-main/scripts/uses_modules.lua")
end

function m.detectsExistingScriptSelections()
	assert(cli.isScriptSelection("test/fixture-main/scripts/uses_modules.lua"))
	assert(not cli.isScriptSelection("test_runner_core"))
end

return m
