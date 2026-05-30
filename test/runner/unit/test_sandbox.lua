local manifestRunner = require("@src/runner/manifest")
local paths = require("@src/runner/paths")
local sandbox = require("@src/runner/sandbox")

local m = {}

local function withMountedSandbox(callback)
	local manifest = manifestRunner.loadManifest("test/runner/fixtures/mounted_wait/manifest.lua")
	local mounts = manifestRunner.getMountsForWorkspace(manifest, nil)
	local box = sandbox.create(mounts)
	box.install()

	local ok, result = pcall(callback, box)

	box.uninstall()
	assert(ok, result)

	return result
end

function m.waitForChildResolvesMountedRootChild()
	withMountedSandbox(function(box)
		local replicatedStorage = box.game:GetService("ReplicatedStorage")
		local generated = replicatedStorage:WaitForChild("Generated")

		assert(generated ~= nil)
		assert(generated.Name == "Generated")
		assert(generated.ClassName == "Folder")
	end)
end

function m.waitForChildResolvesMountedNestedChild()
	withMountedSandbox(function(box)
		local replicatedStorage = box.game:GetService("ReplicatedStorage")
		local lifecycle = replicatedStorage:WaitForChild("Generated")
			:WaitForChild("_Internal")
			:WaitForChild("Lifecycle")

		assert(lifecycle ~= nil)
		assert(lifecycle.Name == "Lifecycle")
		assert(lifecycle.ClassName == "ModuleScript")
	end)
end

function m.waitForChildMatchesPropertyMountResolution()
	withMountedSandbox(function(box)
		local replicatedStorage = box.game:GetService("ReplicatedStorage")
		local fromProperty = replicatedStorage.Generated
		local fromWaitForChild = replicatedStorage:WaitForChild("Generated")

		assert(fromProperty == fromWaitForChild)
	end)
end

function m.findFirstChildResolvesMountedChildren()
	withMountedSandbox(function(box)
		local replicatedStorage = box.game:GetService("ReplicatedStorage")
		local fromFindFirstChild = replicatedStorage:FindFirstChild("Generated")

		assert(fromFindFirstChild ~= nil)
		assert(fromFindFirstChild == replicatedStorage.Generated)
	end)
end

function m.mountedManifestStyleWaitForPathLoadsModule()
	withMountedSandbox(function(box)
		local lifecycle = box.loadFileModule(paths.sourceFilePathWithoutExtension("test/runner/fixtures/mounted_wait/wait_for_path.lua"))
		local lifecycleModule = box.require(lifecycle)

		assert(lifecycle.Name == "Lifecycle")
		assert(lifecycleModule.name == "Lifecycle")
	end)
end

function m.scriptParentInvalidRequireProducesError()
	withMountedSandbox(function(box)
		local replicatedStorage = box.game:GetService("ReplicatedStorage")
		local invalidRequireModule = replicatedStorage:WaitForChild("Generated")
			:WaitForChild("_Internal")
			:WaitForChild("InvalidRequireFromScriptParent")
		local result = box.require(invalidRequireModule)

		assert(result.ok == false)
		assert(result.err:find("Cannot require value of type nil", 1, true) ~= nil)
	end)
end

function m.nestedPlayerScriptsMountsResolveFromBothClientRoots()
	local box = sandbox.create({
		{
			mountPath = "PlayerScripts/Common",
			moduleRoot = paths.normalizeFilesystemPath("test/multi-workspace/src/common/shared"),
		},
	})

	box.install()

	local ok, err = pcall(function()
		local players = box.game:GetService("Players")
		local starterPlayer = box.game:GetService("StarterPlayer")
		local localPlayerCommon = players.LocalPlayer.PlayerScripts.Common
		local starterPlayerCommon = starterPlayer.StarterPlayerScripts.Common

		assert(localPlayerCommon ~= nil)
		assert(starterPlayerCommon ~= nil)
		assert(localPlayerCommon.CommonModule ~= nil)
		assert(starterPlayerCommon.CommonModule ~= nil)
		assert(box.require(localPlayerCommon.CommonModule).divide(12, 3) == 4)
		assert(box.require(starterPlayerCommon.CommonModule).divide(12, 3) == 4)
	end)

	box.uninstall()
	assert(ok, err)
end

function m.fileModulesGetSyntheticScriptInstances()
	local box = sandbox.create({})
	box.install()

	local ok, result = pcall(function()
		local suiteModule = box.loadFileModule(
			paths.sourceFilePathWithoutExtension("test/runner/fixtures/discovered_relative_require/test_relative_require.lua")
		)

		suiteModule.relativeRequireWorks()
		suiteModule.selfRequireWorks()
	end)

	box.uninstall()
	assert(ok, result)
end

return m
