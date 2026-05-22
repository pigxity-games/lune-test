local fs = require("@lune/fs")

local paths = require("./paths")

local manifestRunner = {}

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

function manifestRunner.readManifest(filePath: string): string
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

function manifestRunner.validateManifest(manifest)
	assert(type(manifest) == "table", "manifest must return a table")
	assert(type(manifest.tests) == "table", "manifest.tests must be a table")
	assert(type(manifest.mounts) == "table", "manifest.mounts must be a table")

	for testName, testData in pairs(manifest.tests) do
		assert(type(testName) == "string", "manifest.tests keys must be strings")
		assert(type(testData) == "table", `manifest.tests.{testName} must be a table`)
		assert(type(testData.module) == "string", `manifest.tests.{testName}.module must be a string`)
		assert(type(testData.cases) == "table", `manifest.tests.{testName}.cases must be a table`)
	end

	for serviceName, moduleRoot in pairs(manifest.mounts) do
		assert(type(serviceName) == "string", "manifest.mounts keys must be strings")
		assert(type(moduleRoot) == "string", `manifest.mounts.{serviceName} must be a string`)
	end

	return manifest
end

function manifestRunner.loadManifest(filePath: string)
	local normalizedFilePath = paths.normalizeFilesystemPath(filePath)
	local source = manifestRunner.readManifest(normalizedFilePath)
	local chunk = manifestRunner.compileManifest(source, normalizedFilePath)
	local manifest = manifestRunner.executeManifest(chunk)

	return manifestRunner.validateManifest(manifest), normalizedFilePath
end

return manifestRunner
