local fs = require("@lune/fs")

local fake = require("../fake/index")
local paths = require("./paths")

local sandboxModule = {}

local baseGlobals = getfenv(0)
local realRequire = require

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

local specialMounts = {
	PlayerScripts = {
		serviceName = "Players",
		path = { "LocalPlayer", "PlayerScripts" },
	},
}

local function createInstance(name: string, className: string, parent)
	local instance = fake.Instance.new(className)
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
	child._moduleTree = if parent._moduleTree ~= nil then parent._moduleTree.children[name] else nil

	return child
end

local function startsWithPath(path: string, prefix: string): boolean
	return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function resolveAliasedModuleToFilePath(mounts, modulePath: string): string?
	local aliasName, remainder = modulePath:match("^@([^/]+)(.*)$")

	if aliasName == nil then
		return nil
	end

	local repoRelativePath = paths.normalizeFilesystemPath(paths.pathJoin(aliasName, remainder))

	if fs.isFile(repoRelativePath .. ".lua") then
		return repoRelativePath
	end

	local firstSegment, trailingPath = remainder:match("^/([^/]+)(.*)$")

	if firstSegment ~= nil then
		for _, mount in ipairs(mounts) do
			local normalizedRoot = paths.normalizeFilesystemPath(mount.moduleRoot)
			local rootName = normalizedRoot:match("([^/]+)$")

			if rootName == firstSegment then
				local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(normalizedRoot, trailingPath))

				if fs.isFile(candidatePath .. ".lua") then
					return candidatePath
				end
			end
		end
	end

	return nil
end

local function moduleFilePathFromRequirePath(mounts, modulePath: string): string?
	if modulePath:sub(1, 6) == "@lune/" then
		return nil
	end

	if modulePath:sub(1, 1) == "@" then
		return resolveAliasedModuleToFilePath(mounts, modulePath)
	end

	local candidatePath = paths.normalizeFilesystemPath(modulePath)

	if modulePath:sub(1, 1) == "." or paths.isAbsoluteFilesystemPath(modulePath) then
		return candidatePath
	end

	if fs.isFile(candidatePath .. ".lua") then
		return candidatePath
	end

	return nil
end

function sandboxModule.create(manifestMounts)
	local fileModuleCache = {}
	local mounts = {}
	local mountByInstance = {}
	local sandboxGlobals = setmetatable({}, { __index = baseGlobals })
	local installedGlobalsSnapshot = nil
	local services = {}

	sandboxGlobals._G = sandboxGlobals

	local game = createInstance("game", "DataModel", nil)

	function game:GetService(serviceName: string)
		local service = self._children[serviceName]

		if service == nil then
			error("Unknown service: " .. tostring(serviceName))
		end

		return service
	end

	local function ensureService(serviceName: string)
		local service = services[serviceName]

		if service ~= nil then
			return service
		end

		service = createInstance(serviceName, serviceName, game)

		services[serviceName] = service

		return service
	end

	local function buildModuleTree(moduleRoot: string)
		local tree = {
			children = {},
		}

		if not fs.isDir(moduleRoot) then
			return tree
		end

		for _, entryName in ipairs(fs.readDir(moduleRoot)) do
			local entryPath = paths.normalizeFilesystemPath(paths.pathJoin(moduleRoot, entryName))
			local moduleName = entryName:gsub("%.lua$", "")
			local childTree = tree.children[moduleName]

			if childTree == nil then
				childTree = {
					children = {},
				}
				tree.children[moduleName] = childTree
			end

			if fs.isDir(entryPath) then
				childTree.className = childTree.className or "Folder"
				childTree.children = buildModuleTree(entryPath).children
			elseif fs.isFile(entryPath) and entryName:sub(-4) == ".lua" then
				childTree.className = "ModuleScript"
			end
		end

		return tree
	end

	local function resolveMountedChild(parent, name: string)
		local moduleTree = parent._moduleTree

		if moduleTree == nil then
			return nil
		end

		local childTree = moduleTree.children[name]

		if childTree == nil then
			return nil
		end

		local className = childTree.className or "Folder"
		return createChild(parent, name, className)
	end

	local function registerMount(rootInstance, moduleRoot: string)
		local normalizedModuleRoot = paths.normalizeFilesystemPath(moduleRoot)
		local mount = {
			service = rootInstance,
			root = paths.normalizeRequirePath(normalizedModuleRoot),
			moduleRoot = normalizedModuleRoot,
		}

		table.insert(mounts, mount)
		mountByInstance[rootInstance] = mount
		rootInstance._moduleTree = buildModuleTree(normalizedModuleRoot)
		rootInstance._childResolver = resolveMountedChild

		return mount
	end

	local function ensureMountNode(mountPath: string)
		local segments = paths.splitPath(mountPath)
		assert(#segments > 0, "mount path must not be empty")

		local firstSegment = table.remove(segments, 1)
		local specialMount = specialMounts[mountPath]

		if specialMount ~= nil then
			local node = ensureService(specialMount.serviceName)

			for _, segment in ipairs(specialMount.path) do
				node = createChild(node, segment)
			end

			node.ClassName = firstSegment
			return node
		end

		local node = ensureService(firstSegment)

		for _, segment in ipairs(segments) do
			node = createChild(node, segment)
		end

		return node
	end

	local function mountService(mountPath: string, moduleRoot: string)
		return registerMount(ensureMountNode(mountPath), moduleRoot)
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
		modulePath = paths.normalizeRequirePath(modulePath)

		local mount = findMountForPath(modulePath)

		if mount == nil then
			return nil
		end

		local rest = modulePath:sub(#mount.root + 1)

		if rest:sub(1, 1) == "/" then
			rest = rest:sub(2)
		end

		local node = mount.service

		for _, segment in ipairs(paths.splitPath(rest)) do
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
				return paths.normalizeRequirePath(paths.dirname(currentPath) .. "/" .. path)
			end

			local currentFilePath = sandboxGlobals.__currentFilePath

			if currentFilePath ~= nil then
				return paths.normalizeFilesystemPath(paths.pathJoin(paths.dirname(currentFilePath), path))
			end

			error("Relative require used without a current script: " .. path)
		end

		return paths.normalizeRequirePath(path)
	end

	local function loadFileModule(modulePath: string, scriptInstance)
		modulePath = paths.normalizeFilesystemPath(modulePath)

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
		local fileModulePath = moduleFilePathFromRequirePath(manifestMounts, modulePath)
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

	for _, mountData in ipairs(manifestMounts) do
		mountService(mountData.mountPath, mountData.moduleRoot)
	end

	local function install()
		sandboxGlobals.game = game
		sandboxGlobals.require = robloxRequire

		for globalName, globalValue in pairs(fake) do
			sandboxGlobals[globalName] = globalValue
		end

		for serviceName, service in pairs(services) do
			sandboxGlobals[serviceName] = service
		end

		local keysToInstall = {
			"_G",
			"game",
			"require",
			"script",
			"__currentFilePath",
		}

		for globalName in pairs(fake) do
			table.insert(keysToInstall, globalName)
		end

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

return sandboxModule
