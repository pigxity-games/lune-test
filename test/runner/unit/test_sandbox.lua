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

return m
