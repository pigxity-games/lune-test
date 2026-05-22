local fs = require("@lune/fs")
local serde = require("@lune/serde")

local paths = require("./paths")

local manifestRunner = {}

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

function manifestRunner.readManifest(filePath: string): string
	if not fs.isFile(filePath) and fs.isFile(filePath .. ".lua") then
		filePath ..= ".lua"
	end

	return fs.readFile(filePath)
end

function manifestRunner.compileManifest(source: string, filePath: string)
	local chunk, compileErr = loadstring(source, "@" .. filePath)

	if not chunk then
		error(compileErr, 0)
	end

	return chunk
end

function manifestRunner.executeManifest(chunk)
	local ok, result = xpcall(chunk, traceback)

	if not ok then
		error(result, 0)
	end

	return result
end

local function normalizeModulePath(modulePath: string, manifestFilePath: string)
	local isFileModule = modulePath:sub(1, 1) == "." or paths.isAbsoluteFilesystemPath(modulePath)
	local normalizedModulePath = modulePath

	if isFileModule then
		normalizedModulePath = paths.resolvePathFromFile(manifestFilePath, modulePath)
	end

	return normalizedModulePath, isFileModule
end

local function insertMount(normalizedMounts, mountPath: string, moduleRoot: string, manifestFilePath: string)
	assert(type(mountPath) == "string", "mount path must be a string")
	assert(type(moduleRoot) == "string", `mount {mountPath} must point to a string path`)

	table.insert(normalizedMounts, {
		mountPath = paths.normalizeRequirePath(mountPath),
		moduleRoot = paths.resolveFilesystemPathFromFile(manifestFilePath, moduleRoot),
	})
end

local function flattenMountSpec(normalizedMounts, manifestFilePath: string, mountSpec, prefix: string?)
	assert(type(mountSpec) == "table", "manifest mounts must be a table")

	if prefix ~= nil then
		local rootPath = rawget(mountSpec, "_root")

		if rootPath ~= nil then
			insertMount(normalizedMounts, prefix, rootPath, manifestFilePath)
		end
	end

	for mountName, mountValue in pairs(mountSpec) do
		if mountName ~= "_root" then
			assert(type(mountName) == "string", "manifest mount keys must be strings")

			local mountPath = if prefix == nil then mountName else prefix .. "/" .. mountName

			if type(mountValue) == "string" then
				insertMount(normalizedMounts, mountPath, mountValue, manifestFilePath)
			else
				assert(type(mountValue) == "table", `manifest mount {mountPath} must be a string or table`)
				flattenMountSpec(normalizedMounts, manifestFilePath, mountValue, mountPath)
			end
		end
	end
end

local function normalizeRojoMountPath(mountPath: string): string
	if mountPath == "StarterPlayer/StarterPlayerScripts" then
		return "PlayerScripts"
	end

	return mountPath
end

local function flattenRojoTree(normalizedMounts, manifestFilePath: string, node, pathParts)
	assert(type(node) == "table", "rojo project nodes must be tables")

	local nodePath = rawget(node, "$path")

	if nodePath ~= nil and #pathParts > 0 then
		insertMount(
			normalizedMounts,
			normalizeRojoMountPath(table.concat(pathParts, "/")),
			nodePath,
			manifestFilePath
		)
	end

	for childName, childNode in pairs(node) do
		if type(childName) == "string" and childName:sub(1, 1) ~= "$" then
			local nextPathParts = table.clone(pathParts)
			table.insert(nextPathParts, childName)
			flattenRojoTree(normalizedMounts, manifestFilePath, childNode, nextPathParts)
		end
	end
end

local function mountsFromRojoProject(rojoProjectPath: string)
	local source = fs.readFile(rojoProjectPath)
	local project = serde.decode("json", source)
	local normalizedMounts = {}

	assert(type(project) == "table", "rojo project must decode to a table")
	assert(type(project.tree) == "table", "rojo project.tree must be a table")

	flattenRojoTree(normalizedMounts, rojoProjectPath, project.tree, {})

	return normalizedMounts
end

local function normalizeWorkspaceMounts(workspaceData, manifestFilePath: string)
	assert(type(workspaceData) == "table", "workspace definition must be a table")

	local normalizedMounts = {}

	if workspaceData.mounts ~= nil then
		flattenMountSpec(normalizedMounts, manifestFilePath, workspaceData.mounts)
	end

	if workspaceData.rojoProject ~= nil then
		assert(type(workspaceData.rojoProject) == "string", "workspace.rojoProject must be a string")

		local rojoProjectPath = paths.resolveFilesystemPathFromFile(manifestFilePath, workspaceData.rojoProject)
		local rojoMounts = mountsFromRojoProject(rojoProjectPath)

		for _, mountData in ipairs(rojoMounts) do
			table.insert(normalizedMounts, mountData)
		end
	end

	assert(#normalizedMounts > 0, "workspace must define mounts or rojoProject")

	return normalizedMounts
end

local function normalizeManifestMounts(manifest, manifestFilePath: string)
	local normalizedMounts = {}

	if manifest.mounts ~= nil then
		flattenMountSpec(normalizedMounts, manifestFilePath, manifest.mounts)
	end

	return normalizedMounts
end

local function normalizeTest(testName: string, testData, manifestFilePath: string, manifestMounts, workspaces)
	assert(type(testName) == "string", "manifest.tests keys must be strings")
	assert(type(testData) == "table", `manifest.tests.{testName} must be a table`)
	assert(type(testData.module) == "string", `manifest.tests.{testName}.module must be a string`)
	assert(type(testData.cases) == "table", `manifest.tests.{testName}.cases must be a table`)

	local modulePath, moduleIsFile = normalizeModulePath(testData.module, manifestFilePath)
	local mounts = manifestMounts

	if testData.workspace ~= nil then
		assert(type(testData.workspace) == "string", `manifest.tests.{testName}.workspace must be a string`)

		local workspaceData = workspaces[testData.workspace]
		assert(workspaceData ~= nil, `unknown workspace: {testData.workspace}`)

		mounts = normalizeWorkspaceMounts(workspaceData, manifestFilePath)
	end

	assert(#mounts > 0, `manifest.tests.{testName} must resolve at least one mount`)

	return {
		module = modulePath,
		moduleIsFile = moduleIsFile,
		cases = testData.cases,
		mounts = mounts,
	}
end

function manifestRunner.validateManifest(manifest)
	assert(type(manifest) == "table", "manifest must return a table")
	assert(type(manifest.tests) == "table", "manifest.tests must be a table")

	for testName, testData in pairs(manifest.tests) do
		assert(type(testData.module) == "string", `manifest.tests.{testName}.module must be a string`)
		assert(type(testData.moduleIsFile) == "boolean", `manifest.tests.{testName}.moduleIsFile must be a boolean`)
		assert(type(testData.cases) == "table", `manifest.tests.{testName}.cases must be a table`)
		assert(type(testData.mounts) == "table", `manifest.tests.{testName}.mounts must be a table`)

		for index, mountData in ipairs(testData.mounts) do
			assert(type(mountData) == "table", `manifest.tests.{testName}.mounts[{index}] must be a table`)
			assert(type(mountData.mountPath) == "string", `manifest.tests.{testName}.mounts[{index}].mountPath must be a string`)
			assert(type(mountData.moduleRoot) == "string", `manifest.tests.{testName}.mounts[{index}].moduleRoot must be a string`)
		end
	end

	return manifest
end

local function loadManifestInternal(filePath: string, seenPaths)
	local normalizedFilePath = paths.normalizeFilesystemPath(filePath)
	assert(seenPaths[normalizedFilePath] == nil, `circular child manifest reference: {normalizedFilePath}`)
	seenPaths[normalizedFilePath] = true

	local source = manifestRunner.readManifest(normalizedFilePath)
	local chunk = manifestRunner.compileManifest(source, normalizedFilePath)
	local rawManifest = manifestRunner.executeManifest(chunk)

	assert(type(rawManifest) == "table", "manifest must return a table")

	local normalizedManifest = {
		tests = {},
	}

	local manifestMounts = normalizeManifestMounts(rawManifest, normalizedFilePath)
	local workspaces = rawManifest.workspaces or {}

	if rawManifest.workspaces ~= nil then
		assert(type(rawManifest.workspaces) == "table", "manifest.workspaces must be a table")
	end

	if rawManifest.tests ~= nil then
		assert(type(rawManifest.tests) == "table", "manifest.tests must be a table")

		for testName, testData in pairs(rawManifest.tests) do
			assert(normalizedManifest.tests[testName] == nil, `duplicate test suite: {testName}`)
			normalizedManifest.tests[testName] = normalizeTest(
				testName,
				testData,
				normalizedFilePath,
				manifestMounts,
				workspaces
			)
		end
	end

	if rawManifest.childManifests ~= nil then
		assert(type(rawManifest.childManifests) == "table", "manifest.childManifests must be a table")

		for index, childManifestPath in ipairs(rawManifest.childManifests) do
			assert(type(childManifestPath) == "string", `manifest.childManifests[{index}] must be a string`)

			local childManifest = loadManifestInternal(
				paths.resolveFilesystemPathFromFile(normalizedFilePath, childManifestPath),
				seenPaths
			)

			for testName, testData in pairs(childManifest.tests) do
				assert(normalizedManifest.tests[testName] == nil, `duplicate test suite: {testName}`)
				normalizedManifest.tests[testName] = testData
			end
		end
	end

	seenPaths[normalizedFilePath] = nil

	return manifestRunner.validateManifest(normalizedManifest)
end

function manifestRunner.loadManifest(filePath: string)
	return loadManifestInternal(filePath, {})
end

return manifestRunner
