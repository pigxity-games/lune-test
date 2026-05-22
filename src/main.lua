local fs = require("@lune/fs")
local process = require("@lune/process")

local Instance = require("./fake/Instance")
local Color3 = require("./fake/Color3")
local Vector2 = require("./fake/Vector2")
local Vector3 = require("./fake/Vector3")
local CFrame = require("./fake/CFrame")
local UDim = require("./fake/UDim")
local UDim2 = require("./fake/UDim2")
local BrickColor = require("./fake/BrickColor")

local function pathJoin(...: string): string
	local parts = { ... }
	local path = table.concat(parts, "/")
	path = path:gsub("\\", "/")
	path = path:gsub("/+", "/")
	return path
end

local function normalizeFilesystemPath(path: string): string
	path = path:gsub("\\", "/")

	-- Treat relative args as relative to the terminal cwd
	if not path:match("^/") and not path:match("^%a:[/]") then
		path = pathJoin(process.cwd, path)
	end

	return path
end

local function dirname(path: string): string
	local dir = path:match("^(.*)/[^/]+$")

	if dir == nil or dir == "" then
		return "."
	end

	return dir
end

local function resolvePathFromFile(baseFilePath: string, targetPath: string): string
	if targetPath:sub(1, 1) == "." then
		return normalizeFilesystemPath(pathJoin(dirname(baseFilePath), targetPath))
	end

	return targetPath
end

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

local filePath = process.args[1]
local requestedSuiteName = process.args[2]
assert(filePath, "usage: lune run lune-test <manifest.lua> [suite-name]")

filePath = normalizeFilesystemPath(filePath)

local source = fs.readFile(filePath)

local chunk, compileErr = loadstring(source, "@" .. filePath)
if not chunk then
	error(compileErr, 0)
end

local ok, result = xpcall(chunk, traceback)

if not ok then
	print(result)
	process.exit(1)
end

local manifest = result

assert(type(manifest) == "table", "manifest must return a table")

local baseGlobals = getfenv(0)
local realRequire = require

local function splitPath(path: string): { string }
	local parts = {}

	for part in path:gsub("\\", "/"):gmatch("[^/]+") do
		if part ~= "" and part ~= "." then
			if part == ".." then
				table.remove(parts)
			else
				table.insert(parts, part)
			end
		end
	end

	return parts
end

local function joinParts(parts: { string }): string
	return table.concat(parts, "/")
end

local function normalizePath(path: string): string
	path = path:gsub("\\", "/")
	path = path:gsub("%.luau$", "")
	path = path:gsub("%.lua$", "")
	path = path:gsub("/+$", "")

	return joinParts(splitPath(path))
end

local function resolveAliasedModuleToFilePath(modulePath: string): string?
	local aliasName, remainder = modulePath:match("^@([^/]+)(.*)$")

	if aliasName == nil then
		return nil
	end

	local repoRelativePath = normalizeFilesystemPath(pathJoin(aliasName, remainder))

	if fs.isFile(repoRelativePath .. ".lua") then
		return repoRelativePath
	end

	local firstSegment, trailingPath = remainder:match("^/([^/]+)(.*)$")

	if firstSegment ~= nil then
		for _, moduleRoot in pairs(manifest.mounts) do
			local normalizedRoot = normalizeFilesystemPath(moduleRoot)
			local rootName = normalizedRoot:match("([^/]+)$")

			if rootName == firstSegment then
				local candidatePath = normalizeFilesystemPath(pathJoin(normalizedRoot, trailingPath))

				if fs.isFile(candidatePath .. ".lua") then
					return candidatePath
				end
			end
		end
	end

	return nil
end

local function moduleFilePathFromRequirePath(modulePath: string): string?
	if modulePath:sub(1, 6) == "@lune/" then
		return nil
	end

	if modulePath:sub(1, 1) == "@" then
		return resolveAliasedModuleToFilePath(modulePath)
	end

	local candidatePath = normalizeFilesystemPath(modulePath)

	if modulePath:sub(1, 1) == "." or modulePath:match("^/") or modulePath:match("^%a:[/]") then
		return candidatePath
	end

	if fs.isFile(candidatePath .. ".lua") then
		return candidatePath
	end

	return nil
end

local function createInstance(name: string, className: string, parent)
	local instance = Instance.new(className)
	instance.Name = name

	if parent ~= nil then
		instance.Parent = parent
	end

	return instance
end

local function createChild(parent, name: string, className: string?)
	local child = parent._children[name]

	if child ~= nil then
		return child
	end

	child = createInstance(name, className or "Folder", parent)
	child._childResolver = parent._childResolver

	return child
end

local function startsWithPath(path: string, prefix: string): boolean
	return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function createSandbox()
	local fileModuleCache = {}
	local mounts = {}
	local mountByInstance = {}
	local sandboxGlobals = setmetatable({}, { __index = baseGlobals })
	sandboxGlobals._G = sandboxGlobals

	local game = createInstance("game", "DataModel", nil)

	function game:GetService(serviceName: string)
		local service = self._children[serviceName]

		if service == nil then
			error("Unknown service: " .. tostring(serviceName))
		end

		return service
	end

	local function mountService(serviceName: string, moduleRoot: string)
		local service = createInstance(serviceName, serviceName, game)

		local mount = {
			service = service,
			root = normalizePath(moduleRoot),
		}

		table.insert(mounts, mount)
		mountByInstance[service] = mount
		service._childResolver = function(parent, name: string)
			return createChild(parent, name)
		end

		return service
	end

	local function findMountForPath(modulePath: string)
		local bestMount = nil

		for _, mount in ipairs(mounts) do
			if startsWithPath(modulePath, mount.root) then
				if bestMount == nil or #mount.root > #bestMount.root then
					bestMount = mount
				end
			end
		end

		return bestMount
	end

	local function ensureInstanceForModulePath(modulePath: string)
		modulePath = normalizePath(modulePath)

		local mount = findMountForPath(modulePath)

		if mount == nil then
			return nil
		end

		local rest = modulePath:sub(#mount.root + 1)

		if rest:sub(1, 1) == "/" then
			rest = rest:sub(2)
		end

		local node = mount.service

		for _, segment in ipairs(splitPath(rest)) do
			node = createChild(node, segment)
		end

		node.ClassName = "ModuleScript"

		return node
	end

	local function modulePathFromInstance(instance): string
		local parts = {}
		local node = instance

		while node ~= nil do
			local mount = mountByInstance[node]

			if mount ~= nil then
				if #parts == 0 then
					return mount.root
				end

				return mount.root .. "/" .. table.concat(parts, "/")
			end

			table.insert(parts, 1, node.Name)
			node = node.Parent
		end

		error("Instance is not under a mounted service: " .. tostring(instance))
	end

	local function resolveStringRequire(path: string): string
		if path:sub(1, 1) == "." then
			local currentScript = sandboxGlobals.script

			if currentScript ~= nil then
				local currentPath = modulePathFromInstance(currentScript)
				return normalizePath(dirname(currentPath) .. "/" .. path)
			end

			local currentFilePath = sandboxGlobals.__currentFilePath

			if currentFilePath ~= nil then
				return normalizeFilesystemPath(pathJoin(dirname(currentFilePath), path))
			end

			error("Relative require used without a current script: " .. path)
		end

		return normalizePath(path)
	end

	local function loadFileModule(modulePath: string, scriptInstance)
		modulePath = normalizeFilesystemPath(modulePath)

		local cached = fileModuleCache[modulePath]

		if cached ~= nil then
			return cached
		end

		local moduleSource = fs.readFile(modulePath .. ".lua")
		local moduleChunk, moduleCompileErr = loadstring(moduleSource, "@" .. modulePath)

		if not moduleChunk then
			error(moduleCompileErr, 0)
		end

		setfenv(moduleChunk, sandboxGlobals)

		local oldScript = sandboxGlobals.script
		local oldCurrentFilePath = sandboxGlobals.__currentFilePath

		sandboxGlobals.script = scriptInstance
		sandboxGlobals.__currentFilePath = modulePath

		local moduleOk, moduleResult = xpcall(moduleChunk, traceback)

		sandboxGlobals.script = oldScript
		sandboxGlobals.__currentFilePath = oldCurrentFilePath

		if not moduleOk then
			error(moduleResult, 0)
		end

		fileModuleCache[modulePath] = moduleResult

		return moduleResult
	end

	local function requireWithScript(modulePath: string, scriptInstance)
		local fileModulePath = moduleFilePathFromRequirePath(modulePath)
		local loader = realRequire
		local loadTarget = modulePath

		if fileModulePath ~= nil then
			loader = loadFileModule
			loadTarget = fileModulePath
		end

		local ok, result = pcall(loader, loadTarget, scriptInstance)

		if not ok then
			error(result, 2)
		end

		return result
	end

	local function robloxRequire(target)
		if type(target) == "string" then
			local modulePath = resolveStringRequire(target)
			local scriptInstance = ensureInstanceForModulePath(modulePath)

			return requireWithScript(modulePath, scriptInstance)
		end

		if type(target) == "table" and target._isFakeRobloxInstance then
			local modulePath = modulePathFromInstance(target)

			target.ClassName = "ModuleScript"

			return requireWithScript(modulePath, target)
		end

		error("Cannot require value of type " .. typeof(target))
	end

	local services = {}

	for serviceName, moduleRoot in pairs(manifest.mounts) do
		services[serviceName] = mountService(serviceName, moduleRoot)
	end

	local installedGlobalsSnapshot = nil

	local function install()
		sandboxGlobals.game = game
		sandboxGlobals.require = robloxRequire

		sandboxGlobals.Instance = Instance
		sandboxGlobals.Color3 = Color3
		sandboxGlobals.Vector2 = Vector2
		sandboxGlobals.Vector3 = Vector3
		sandboxGlobals.CFrame = CFrame
		sandboxGlobals.UDim = UDim
		sandboxGlobals.UDim2 = UDim2
		sandboxGlobals.BrickColor = BrickColor

		for serviceName, service in pairs(services) do
			sandboxGlobals[serviceName] = service
		end

		local keysToInstall = {
			"_G",
			"game",
			"require",
			"script",
			"__currentFilePath",
			"Instance",
			"Color3",
			"Vector2",
			"Vector3",
			"CFrame",
			"UDim",
			"UDim2",
			"BrickColor",
		}

		for serviceName in pairs(services) do
			table.insert(keysToInstall, serviceName)
		end

		installedGlobalsSnapshot = {}

		for _, key in ipairs(keysToInstall) do
			installedGlobalsSnapshot[key] = baseGlobals[key]
			baseGlobals[key] = sandboxGlobals[key]
		end
	end

	local function uninstall()
		if installedGlobalsSnapshot == nil then
			return
		end

		for key, value in pairs(installedGlobalsSnapshot) do
			baseGlobals[key] = value
		end

		installedGlobalsSnapshot = nil
	end

	return {
		game = game,
		services = services,
		globals = sandboxGlobals,
		require = robloxRequire,
		loadFileModule = loadFileModule,
		install = install,
		uninstall = uninstall,
	}
end

local function withTraceback(err)
    return debug.traceback(tostring(err), 2)
end

local function caseArgsFromValue(caseValue)
	if type(caseValue) == "function" then
		caseValue = caseValue()
	end

	if caseValue == nil then
		return {}
	end

	if type(caseValue) == "table" then
		return caseValue
	end

	return { caseValue }
end

local out = ""
totalSuccess = 0
total = 0
local matchedSuiteCount = 0

for testName, testData in pairs(manifest.tests) do
	if requestedSuiteName == nil or requestedSuiteName == testName then
		matchedSuiteCount += 1
		print(`[TEST]: {testName}`)
		
		local modulePath = resolvePathFromFile(filePath, testData.module)
		
		for caseName, deps in pairs(testData.cases) do
			total += 1
			local sandbox = createSandbox()
			sandbox.install()

			local success, result = xpcall(function()
				local module = if testData.module:sub(1, 1) == "." then sandbox.loadFileModule(modulePath) else sandbox.require(testData.module)
				local caseArgs = caseArgsFromValue(deps)
				return module[caseName](unpack(caseArgs))
			end, withTraceback)
			sandbox.uninstall()
			
			local text = if success then "PASS" else "FAIL"
			print(`- [{text}]: {caseName}`)

			if not success then
				out = out .. "'" .. caseName .. "'" .. "\nTRACEBACK:\n" .. result
			else
				totalSuccess += 1
			end
		end
	end
end

if requestedSuiteName ~= nil and matchedSuiteCount == 0 then
	error(`unknown test suite: {requestedSuiteName}`, 0)
end

if out ~= "" then
	print("\nCOLLECTED ERRORS:\n")
	print(out)
end
print(`\nTEST RESULTS: {totalSuccess}/{total} PASSED\n`)
