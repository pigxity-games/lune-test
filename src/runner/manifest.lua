local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local paths = require("./paths")

local manifestRunner = {}

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

function manifestRunner.readManifest(filePath: string): string
	local sourceFilePath = paths.resolveExistingSourceFile(filePath) or filePath

	return fs.readFile(sourceFilePath)
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
		normalizedModulePath =
			paths.sourceFilePathWithoutExtension(paths.resolvePathFromFile(manifestFilePath, modulePath))
	end

	return normalizedModulePath, isFileModule
end

local function pathHasWildcard(path: string): boolean
	return path:find("*", 1, true) ~= nil
end

local function segmentMatches(patternSegment: string, pathSegment: string): boolean
	if patternSegment == "**" then
		return true
	end

	local regex = "^" .. patternSegment:gsub("([%%%^%$%(%)%.%[%]%+%-%?])", "%%%1"):gsub("%*", ".*") .. "$"
	return pathSegment:match(regex) ~= nil
end

local function pathSegmentsMatch(patternSegments, pathSegments, patternIndex: number, pathIndex: number): boolean
	while true do
		if patternIndex > #patternSegments then
			return pathIndex > #pathSegments
		end

		local patternSegment = patternSegments[patternIndex]

		if patternSegment == "**" then
			if patternIndex == #patternSegments then
				return true
			end

			for nextPathIndex = pathIndex, #pathSegments + 1 do
				if pathSegmentsMatch(patternSegments, pathSegments, patternIndex + 1, nextPathIndex) then
					return true
				end
			end

			return false
		end

		if pathIndex > #pathSegments or not segmentMatches(patternSegment, pathSegments[pathIndex]) then
			return false
		end

		patternIndex += 1
		pathIndex += 1
	end
end

local function globMatchesPath(pattern: string, filePath: string): boolean
	return pathSegmentsMatch(paths.splitPath(pattern), paths.splitPath(filePath), 1, 1)
end

local function listFilesRecursive(rootPath: string, results)
	if fs.isFile(rootPath) then
		table.insert(results, paths.normalizeFilesystemPath(rootPath))
		return
	end

	if not fs.isDir(rootPath) then
		return
	end

	for _, entryName in ipairs(fs.readDir(rootPath)) do
		local entryPath = paths.normalizeFilesystemPath(paths.pathJoin(rootPath, entryName))

		if fs.isDir(entryPath) then
			listFilesRecursive(entryPath, results)
		elseif fs.isFile(entryPath) then
			table.insert(results, entryPath)
		end
	end
end

local function discoveredTestName(manifestFilePath: string, sourceFilePath: string): string
	local manifestDirParts = paths.splitPath(paths.dirname(manifestFilePath))
	local sourcePathParts = paths.splitPath(paths.sourceFilePathWithoutExtension(sourceFilePath))
	local isUnderManifestDir = #sourcePathParts > #manifestDirParts

	if isUnderManifestDir then
		for index, manifestDirPart in ipairs(manifestDirParts) do
			if sourcePathParts[index]:lower() ~= manifestDirPart:lower() then
				isUnderManifestDir = false
				break
			end
		end
	end

	if isUnderManifestDir then
		local relativeParts = {}

		for index = #manifestDirParts + 1, #sourcePathParts do
			table.insert(relativeParts, sourcePathParts[index])
		end

		return table.concat(relativeParts, "/")
	end

	return paths.normalizeRequirePath(paths.sourceFilePathWithoutExtension(sourceFilePath))
end

local function discoverTestsFromLocations(testLocations, manifestFilePath: string, manifestMounts)
	assert(type(testLocations) == "table", "manifest.testLocations must be a table")

	local discoveredTests = {}

	for index, locationPattern in ipairs(testLocations) do
		assert(type(locationPattern) == "string", `manifest.testLocations[{index}] must be a string`)

		local resolvedPattern = paths.resolveManifestResourcePath(manifestFilePath, locationPattern)
		local patternParts = paths.splitPath(resolvedPattern)
		local staticParts = {}

		for _, segment in ipairs(patternParts) do
			if pathHasWildcard(segment) then
				break
			end

			table.insert(staticParts, segment)
		end

		local searchRoot = if #staticParts == 0 then process.cwd else paths.joinParts(staticParts)
		local candidateFiles = {}
		listFilesRecursive(searchRoot, candidateFiles)

		for _, candidateFile in ipairs(candidateFiles) do
			if
				candidateFile:match("%.luau?$")
				and globMatchesPath(resolvedPattern, paths.sourceFilePathWithoutExtension(candidateFile))
			then
				local testName = discoveredTestName(manifestFilePath, candidateFile)

				assert(discoveredTests[testName] == nil, `duplicate test suite: {testName}`)

				discoveredTests[testName] = {
					module = paths.sourceFilePathWithoutExtension(candidateFile),
					moduleIsFile = true,
					cases = {},
					mounts = manifestMounts,
					discoverCases = true,
				}
			end
		end
	end

	return discoveredTests
end

local function mergeDiscoveredTests(
	normalizedTests,
	testLocations,
	manifestFilePath: string,
	mounts,
	errorPrefix: string
)
	local discoveredTests = discoverTestsFromLocations(testLocations, manifestFilePath, mounts)

	for testName, testData in pairs(discoveredTests) do
		assert(normalizedTests[testName] == nil, `{errorPrefix}: {testName}`)
		normalizedTests[testName] = testData
	end
end

local function insertMount(normalizedMounts, mountPath: string, moduleRoot: string, manifestFilePath: string)
	assert(type(mountPath) == "string", "mount path must be a string")
	assert(type(moduleRoot) == "string", `mount {mountPath} must point to a string path`)

	table.insert(normalizedMounts, {
		mountPath = paths.normalizeRequirePath(mountPath),
		moduleRoot = paths.resolveManifestResourcePath(manifestFilePath, moduleRoot),
	})
end

local function insertRojoMount(normalizedMounts, mountPath: string, moduleRoot: string, rojoProjectPath: string)
	assert(type(mountPath) == "string", "mount path must be a string")
	assert(type(moduleRoot) == "string", `mount {mountPath} must point to a string path`)

	table.insert(normalizedMounts, {
		mountPath = paths.normalizeRequirePath(mountPath),
		moduleRoot = paths.resolveFilesystemPathFromFile(rojoProjectPath, moduleRoot),
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
		insertRojoMount(
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

		local rojoProjectPath = paths.resolveManifestResourcePath(manifestFilePath, workspaceData.rojoProject)
		local rojoMounts = mountsFromRojoProject(rojoProjectPath)

		for _, mountData in ipairs(rojoMounts) do
			table.insert(normalizedMounts, mountData)
		end
	end

	assert(#normalizedMounts > 0, "workspace must define mounts or rojoProject")

	return normalizedMounts
end

local function normalizeWorkspaces(rawWorkspaces, manifestFilePath: string)
	local normalizedWorkspaces = {}

	for workspaceName, workspaceData in pairs(rawWorkspaces) do
		assert(type(workspaceName) == "string", "manifest.workspaces keys must be strings")
		assert(type(workspaceData) == "table", `manifest.workspaces.{workspaceName} must be a table`)

		normalizedWorkspaces[workspaceName] = {
			mounts = normalizeWorkspaceMounts(workspaceData, manifestFilePath),
		}
	end

	return normalizedWorkspaces
end

local function normalizeManifestMounts(manifest, manifestFilePath: string)
	local normalizedMounts = {}

	if manifest.mounts ~= nil then
		flattenMountSpec(normalizedMounts, manifestFilePath, manifest.mounts)
	end

	if manifest.rojoProject ~= nil then
		assert(type(manifest.rojoProject) == "string", "manifest.rojoProject must be a string")

		local rojoProjectPath = paths.resolveManifestResourcePath(manifestFilePath, manifest.rojoProject)
		local rojoMounts = mountsFromRojoProject(rojoProjectPath)

		for _, mountData in ipairs(rojoMounts) do
			table.insert(normalizedMounts, mountData)
		end
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

		mounts = workspaceData.mounts
	end

	assert(#mounts > 0, `manifest.tests.{testName} must resolve at least one mount`)

	return {
		module = modulePath,
		moduleIsFile = moduleIsFile,
		cases = testData.cases,
		mounts = mounts,
		discoverCases = false,
	}
end

function manifestRunner.validateManifest(manifest)
	assert(type(manifest) == "table", "manifest must return a table")
	assert(type(manifest.tests) == "table", "manifest.tests must be a table")
	assert(type(manifest.mounts) == "table", "manifest.mounts must be a table")
	assert(type(manifest.workspaces) == "table", "manifest.workspaces must be a table")
	assert(type(manifest.manifestFilePath) == "string", "manifest.manifestFilePath must be a string")

	for testName, testData in pairs(manifest.tests) do
		assert(type(testData.module) == "string", `manifest.tests.{testName}.module must be a string`)
		assert(type(testData.moduleIsFile) == "boolean", `manifest.tests.{testName}.moduleIsFile must be a boolean`)
		assert(type(testData.cases) == "table", `manifest.tests.{testName}.cases must be a table`)
		assert(type(testData.mounts) == "table", `manifest.tests.{testName}.mounts must be a table`)
		assert(type(testData.discoverCases) == "boolean", `manifest.tests.{testName}.discoverCases must be a boolean`)

		for index, mountData in ipairs(testData.mounts) do
			assert(type(mountData) == "table", `manifest.tests.{testName}.mounts[{index}] must be a table`)
			assert(
				type(mountData.mountPath) == "string",
				`manifest.tests.{testName}.mounts[{index}].mountPath must be a string`
			)
			assert(
				type(mountData.moduleRoot) == "string",
				`manifest.tests.{testName}.mounts[{index}].moduleRoot must be a string`
			)
		end
	end

	for index, mountData in ipairs(manifest.mounts) do
		assert(type(mountData) == "table", `manifest.mounts[{index}] must be a table`)
		assert(type(mountData.mountPath) == "string", `manifest.mounts[{index}].mountPath must be a string`)
		assert(type(mountData.moduleRoot) == "string", `manifest.mounts[{index}].moduleRoot must be a string`)
	end

	for workspaceName, workspaceData in pairs(manifest.workspaces) do
		assert(type(workspaceName) == "string", "manifest.workspaces keys must be strings")
		assert(type(workspaceData) == "table", `manifest.workspaces.{workspaceName} must be a table`)
		assert(type(workspaceData.mounts) == "table", `manifest.workspaces.{workspaceName}.mounts must be a table`)
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
		mounts = {},
		workspaces = {},
		manifestFilePath = normalizedFilePath,
	}

	local manifestMounts = normalizeManifestMounts(rawManifest, normalizedFilePath)
	local workspaces = normalizeWorkspaces(rawManifest.workspaces or {}, normalizedFilePath)
	normalizedManifest.mounts = manifestMounts
	normalizedManifest.workspaces = workspaces

	if rawManifest.workspaces ~= nil then
		assert(type(rawManifest.workspaces) == "table", "manifest.workspaces must be a table")
	end

	if rawManifest.tests ~= nil then
		assert(type(rawManifest.tests) == "table", "manifest.tests must be a table")

		for testName, testData in pairs(rawManifest.tests) do
			assert(normalizedManifest.tests[testName] == nil, `duplicate test suite: {testName}`)
			normalizedManifest.tests[testName] =
				normalizeTest(testName, testData, normalizedFilePath, manifestMounts, workspaces)
		end
	end

	if rawManifest.testLocations ~= nil then
		mergeDiscoveredTests(
			normalizedManifest.tests,
			rawManifest.testLocations,
			normalizedFilePath,
			manifestMounts,
			"duplicate test suite"
		)
	end

	if rawManifest.workspaces ~= nil then
		for workspaceName, workspaceData in pairs(rawManifest.workspaces) do
			if workspaceData.testLocations ~= nil then
				mergeDiscoveredTests(
					normalizedManifest.tests,
					workspaceData.testLocations,
					normalizedFilePath,
					workspaces[workspaceName].mounts,
					`duplicate test suite in workspace {workspaceName}`
				)
			end
		end
	end

	if rawManifest.childManifests ~= nil then
		assert(type(rawManifest.childManifests) == "table", "manifest.childManifests must be a table")

		for index, childManifestPath in ipairs(rawManifest.childManifests) do
			assert(type(childManifestPath) == "string", `manifest.childManifests[{index}] must be a string`)

			local childManifest = loadManifestInternal(
				paths.resolveManifestResourcePath(normalizedFilePath, childManifestPath),
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

function manifestRunner.getMountsForWorkspace(manifest, workspaceName: string?)
	if workspaceName == nil then
		return manifest.mounts
	end

	local workspaceData = manifest.workspaces[workspaceName]
	assert(workspaceData ~= nil, `unknown workspace: {workspaceName}`)

	return workspaceData.mounts
end

function manifestRunner.inferWorkspaceForScript(manifest, scriptPath: string): string?
	local relativePath = paths.relativeFilesystemPath(paths.dirname(manifest.manifestFilePath), scriptPath)

	if relativePath == nil then
		return nil
	end

	local normalizedRelativePath = relativePath:lower()
	local matchedWorkspaceName = nil

	for workspaceName in pairs(manifest.workspaces) do
		local workspacePattern = "%f[%w]" .. workspaceName:lower():gsub("([^%w])", "%%%1") .. "%f[^%w]"

		if normalizedRelativePath:match(workspacePattern) ~= nil then
			if matchedWorkspaceName ~= nil then
				return nil
			end

			matchedWorkspaceName = workspaceName
		end
	end

	return matchedWorkspaceName
end

function manifestRunner.getMountsForScript(manifest, scriptPath: string, explicitWorkspaceName: string?): { any }
	if explicitWorkspaceName ~= nil then
		return manifestRunner.getMountsForWorkspace(manifest, explicitWorkspaceName)
	end

	if #manifest.mounts > 0 then
		return manifest.mounts
	end

	local inferredWorkspaceName = manifestRunner.inferWorkspaceForScript(manifest, scriptPath)

	if inferredWorkspaceName ~= nil then
		return manifestRunner.getMountsForWorkspace(manifest, inferredWorkspaceName)
	end

	if next(manifest.workspaces) ~= nil then
		error("script requires a workspace; pass -w/--workspace or name the script to match one workspace", 0)
	end

	return manifest.mounts
end

function manifestRunner.findNearestManifest(startPath: string): string?
	local currentPath = paths.normalizeFilesystemPath(startPath)

	if
		paths.isSourceFilePath(currentPath)
		or fs.isFile(currentPath)
		or paths.resolveExistingSourceFile(currentPath) ~= nil
	then
		currentPath = paths.dirname(currentPath)
	end

	while true do
		local candidatePath = paths.pathJoin(currentPath, "manifest")
		local manifestPath = paths.resolveExistingSourceFile(candidatePath)

		if manifestPath ~= nil then
			return manifestPath
		end

		local parentPath = paths.dirname(currentPath)

		if parentPath == currentPath then
			return nil
		end

		currentPath = parentPath
	end
end

return manifestRunner
