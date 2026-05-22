local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

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
assert(filePath, "usage: lune run src/test.lua <file.lua>")

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

local globals = getfenv(0)
local realRequire = require
local fileModuleCache = {}

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

	local oldScript = globals.script
	local oldCurrentFilePath = globals.__currentFilePath

	globals.script = scriptInstance
	globals.__currentFilePath = modulePath

	local moduleOk, moduleResult = xpcall(moduleChunk, traceback)

	globals.script = oldScript
	globals.__currentFilePath = oldCurrentFilePath

	if not moduleOk then
		error(moduleResult, 0)
	end

	fileModuleCache[modulePath] = moduleResult

	return moduleResult
end

local Instance = realRequire("./fake/Instance")
local Color3 = realRequire("./fake/Color3")
local Vector2 = realRequire("./fake/Vector2")
local Vector3 = realRequire("./fake/Vector3")
local CFrame = realRequire("./fake/CFrame")
local UDim = realRequire("./fake/UDim")
local UDim2 = realRequire("./fake/UDim2")
local BrickColor = realRequire("./fake/BrickColor")

local mounts = {}
local mountByInstance = {}

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

local function readRequireAliases(): { [string]: string }
	local luaurcPath = pathJoin(process.cwd, ".luaurc")

	if not fs.isFile(luaurcPath) then
		return {}
	end

	local config = serde.decode("json", fs.readFile(luaurcPath))
	local aliases = {}

	for aliasName, aliasPath in pairs(config.aliases or {}) do
		if type(aliasName) == "string" and type(aliasPath) == "string" then
			aliases[aliasName] = normalizeFilesystemPath(aliasPath)
		end
	end

	return aliases
end

local requireAliases = readRequireAliases()

local function resolveAliasedModuleToFilePath(modulePath: string): string?
	local aliasName, remainder = modulePath:match("^@([^/]+)(.*)$")

	if aliasName == nil then
		return nil
	end

	local aliasRoot = requireAliases[aliasName]

	if aliasRoot ~= nil then
		return normalizeFilesystemPath(pathJoin(aliasRoot, remainder))
	end

	local repoRelativePath = normalizeFilesystemPath(pathJoin(aliasName, remainder))

	if fs.isFile(repoRelativePath .. ".lua") then
		return repoRelativePath
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

local function startsWithPath(path: string, prefix: string): boolean
	return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
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
		local currentScript = globals.script

		if currentScript ~= nil then
			local currentPath = modulePathFromInstance(currentScript)
			return normalizePath(dirname(currentPath) .. "/" .. path)
		end

		local currentFilePath = globals.__currentFilePath

		if currentFilePath ~= nil then
			return normalizeFilesystemPath(pathJoin(dirname(currentFilePath), path))
		end

		error("Relative require used without a current script: " .. path)
	end

	return normalizePath(path)
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

local function withTraceback(err)
    return debug.traceback(tostring(err), 2)
end

globals.game = game
globals.require = robloxRequire

globals.Instance = Instance
globals.Color3 = Color3
globals.Vector2 = Vector2
globals.Vector3 = Vector3
globals.CFrame = CFrame
globals.UDim = UDim
globals.UDim2 = UDim2
globals.BrickColor = BrickColor

for serviceName, moduleRoot in pairs(manifest.mounts) do
	local mounted = mountService(serviceName, moduleRoot)
	globals[serviceName] = mounted
end

local out = ""
totalSuccess = 0
total = 0

for testName, testData in pairs(manifest.tests) do
	print(`[TEST]: {testName}`)
	
	local modulePath = resolvePathFromFile(filePath, testData.module)
	local module = if testData.module:sub(1, 1) == "." then loadFileModule(modulePath) else realRequire(testData.module)
	
	for caseName, deps in pairs(testData.cases) do
		total += 1
		local success, result = xpcall(module[caseName], withTraceback)
		
		local text = if success then "PASS" else "FAIL"
		print(`- [{text}]: {caseName}`)

		if not success then
			out = out .. "'" .. caseName .. "'" .. "\nTRACEBACK:\n" .. result
		else
			totalSuccess += 1
		end
	end
end

if out ~= "" then
	print("\nCOLLECTED ERRORS:\n")
	print(out)
end
print(`\nTEST RESULTS: {totalSuccess}/{total} PASSED\n`)
