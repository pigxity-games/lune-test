local cli = require("./cli")
local manifestRunner = require("./manifest")
local paths = require("./paths")
local runner = require("./run")

local command = {}

local DEFAULT_MANIFEST_PATH = "test/manifest.lua"

local function normalizeManifestPath(manifestPath: string): string
	local sourceFilePath = paths.resolveExistingSourceFile(manifestPath)

	if sourceFilePath ~= nil then
		return sourceFilePath
	end

	return paths.normalizeFilesystemPath(manifestPath)
end

local function displayPath(path: string): string
	local relativePath = paths.relativeFilesystemPath(".", path)

	return if relativePath ~= nil and relativePath ~= "" then relativePath else paths.normalizeFilesystemPath(path)
end

local function loadManifestCached(manifestCache, manifestPath: string)
	local normalizedManifestPath = normalizeManifestPath(manifestPath)
	local cachedManifest = manifestCache[normalizedManifestPath]

	if cachedManifest ~= nil then
		return cachedManifest, normalizedManifestPath
	end

	local manifest = manifestRunner.loadManifest(normalizedManifestPath)
	manifestCache[normalizedManifestPath] = manifest

	return manifest, normalizedManifestPath
end

local function resolveScriptManifestPath(scriptPath: string, explicitManifestPath: string?): string
	if explicitManifestPath ~= nil then
		return explicitManifestPath
	end

	local nearestManifestPath = manifestRunner.findNearestManifest(scriptPath)

	if nearestManifestPath ~= nil then
		return nearestManifestPath
	end

	return DEFAULT_MANIFEST_PATH
end

function command.buildSelections(options)
	local manifestCache = {}
	local plannedSelections = {}
	local defaultManifest = nil
	local hasScriptSelection = false

	local function getDefaultManifest()
		if defaultManifest == nil then
			local manifest = loadManifestCached(manifestCache, options.manifestPath or DEFAULT_MANIFEST_PATH)
			defaultManifest = manifest
		end

		return defaultManifest
	end

	if #options.selections == 0 then
		assert(#(options.scriptArgs or {}) == 0, "-a requires at least one script selection")

		table.insert(plannedSelections, {
			kind = "manifest",
			manifest = getDefaultManifest(),
		})

		return plannedSelections
	end

	for _, selection in ipairs(options.selections) do
		if cli.isScriptSelection(selection) then
			local sourceFilePath = paths.resolveExistingSourceFile(selection)
			assert(sourceFilePath ~= nil, `script file not found: {selection}`)

			local manifest, manifestPath =
				loadManifestCached(manifestCache, resolveScriptManifestPath(sourceFilePath, options.manifestPath))

			hasScriptSelection = true
			table.insert(plannedSelections, {
				kind = "script",
				filePath = paths.sourceFilePathWithoutExtension(sourceFilePath),
				displayName = displayPath(sourceFilePath),
				manifest = manifest,
				manifestPath = manifestPath,
				scriptArgs = options.scriptArgs or {},
				mounts = manifestRunner.getMountsForScript(
					manifest,
					paths.sourceFilePathWithoutExtension(sourceFilePath),
					options.workspaceName
				),
			})
		else
			table.insert(plannedSelections, {
				kind = "suite",
				suiteName = selection,
				manifest = getDefaultManifest(),
			})
		end
	end

	assert(hasScriptSelection or #(options.scriptArgs or {}) == 0, "-a requires at least one script selection")

	return plannedSelections
end

function command.run(args)
	local options = cli.parseArgs(args)
	local selections = command.buildSelections(options)

	return runner.runSelections(selections)
end

return command
