local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Environment = require("../fake/Environment")
local fake = require("../fake/index")
local paths = require("./paths")

local sandboxModule = {}

local baseGlobals = getfenv(0)
local realRequire = require
local cachedLuaurcAliases = nil
local warnedFallbacks = {}

local function traceback(err)
	return debug.traceback(tostring(err), 2)
end

local specialMounts = {
	PlayerScripts = {
		nodes = {
			{
				serviceName = "Players",
				path = { "LocalPlayer", "PlayerScripts" },
				className = "PlayerScripts",
			},
			{
				serviceName = "StarterPlayer",
				path = { "StarterPlayerScripts" },
				className = "StarterPlayerScripts",
			},
		},
	},
}

local function startsWithPath(path: string, prefix: string): boolean
	return path == prefix or path:sub(1, #prefix + 1) == prefix .. "/"
end

local function warnFallback(key: string, message: string)
	if warnedFallbacks[key] then
		return
	end

	warnedFallbacks[key] = true
	print("WARNING: " .. message)
end

local function getLuaurcAliases()
	if cachedLuaurcAliases ~= nil then
		return cachedLuaurcAliases
	end

	cachedLuaurcAliases = {}

	local luaurcPath = paths.normalizeFilesystemPath(".luaurc")

	if not fs.isFile(luaurcPath) then
		return cachedLuaurcAliases
	end

	local ok, decoded = pcall(function()
		return serde.decode("json", fs.readFile(luaurcPath))
	end)

	if not ok or type(decoded) ~= "table" or type(decoded.aliases) ~= "table" then
		return cachedLuaurcAliases
	end

	for aliasName, aliasPath in pairs(decoded.aliases) do
		if type(aliasName) == "string" and type(aliasPath) == "string" then
			cachedLuaurcAliases[aliasName] = aliasPath
		end
	end

	return cachedLuaurcAliases
end

local function resolveLuaurcAlias(aliasName: string, remainder: string): string?
	local aliasPath = getLuaurcAliases()[aliasName]

	if aliasPath == nil or aliasPath:sub(1, 1) == "~" then
		return nil
	end

	local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(aliasPath, remainder))

	if paths.resolveExistingSourceFile(candidatePath) ~= nil then
		return candidatePath
	end

	return nil
end

local function resolveAliasedModuleToFilePath(mounts, modulePath: string): string?
	local aliasName, remainder = modulePath:match("^@([^/]+)(.*)$")

	if aliasName == nil then
		return nil
	end

	if aliasName == "game" then
		local virtualPath = paths.normalizeRequirePath(remainder)
		local bestCandidate = nil
		local bestMountLength = -1

		for _, mount in ipairs(mounts) do
			local mountPath = paths.normalizeRequirePath(mount.mountPath)

			if startsWithPath(virtualPath, mountPath) then
				local trailingPath = virtualPath:sub(#mountPath + 1)

				if trailingPath:sub(1, 1) == "/" then
					trailingPath = trailingPath:sub(2)
				end

				local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(mount.moduleRoot, trailingPath))

				if paths.resolveExistingSourceFile(candidatePath) ~= nil and #mountPath > bestMountLength then
					bestCandidate = candidatePath
					bestMountLength = #mountPath
				end
			end
		end

		return bestCandidate
	end

	local aliasedPath = resolveLuaurcAlias(aliasName, remainder)

	if aliasedPath ~= nil then
		return aliasedPath
	end

	local repoRelativePath = paths.normalizeFilesystemPath(paths.pathJoin(aliasName, remainder))

	if paths.resolveExistingSourceFile(repoRelativePath) ~= nil then
		warnFallback(
			"repo:" .. modulePath,
			`Falling back to repo-relative alias resolution for "{modulePath}" -> "{repoRelativePath}"`
		)
		return repoRelativePath
	end

	local firstSegment, trailingPath = remainder:match("^/([^/]+)(.*)$")

	if firstSegment ~= nil then
		for _, mount in ipairs(mounts) do
			local normalizedRoot = paths.normalizeFilesystemPath(mount.moduleRoot)
			local rootName = normalizedRoot:match("([^/]+)$")

			if rootName == firstSegment then
				local candidatePath = paths.normalizeFilesystemPath(paths.pathJoin(normalizedRoot, trailingPath))

				if paths.resolveExistingSourceFile(candidatePath) ~= nil then
					warnFallback(
						"mount:" .. modulePath,
						`Falling back to mounted-root alias resolution for "{modulePath}" -> "{candidatePath}"`
					)
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

	if paths.resolveExistingSourceFile(candidatePath) ~= nil then
		return candidatePath
	end

	return nil
end

function sandboxModule.create(manifestMounts, runtimeConfig)
	local fileModuleCache = {}
	local mounts = {}
	local mountByInstance = {}
	local environment = fake.createEnvironment(runtimeConfig)
	local sandboxGlobals = setmetatable({}, { __index = baseGlobals })
	local installedGlobalsSnapshot = nil
	local installedGlobalPresence = {}
	local installedKeys = {}
	local services = environment._services
	local game = environment.game
	local robloxRequire

	local controller = {}

	local function composeSandboxValues(targetEnvironment, includeCustomGlobals)
		local values = {}

		for key, value in pairs(targetEnvironment.globals) do
			values[key] = value
		end

		for key, value in pairs(fake) do
			values[key] = value
		end

		values._G = sandboxGlobals
		values.game = targetEnvironment.game
		values.require = robloxRequire
		values.script = sandboxGlobals.script
		values.__currentFilePath = sandboxGlobals.__currentFilePath

		if includeCustomGlobals then
			for key, value in pairs(targetEnvironment._customGlobals or {}) do
				values[key] = value
			end
		end

		return values
	end

	local function captureCustomGlobals(targetEnvironment)
		local baseline = composeSandboxValues(targetEnvironment, false)
		local customGlobals = {}

		for key, value in pairs(sandboxGlobals) do
			if baseline[key] ~= value then
				customGlobals[key] = value
			end
		end

		targetEnvironment._customGlobals = customGlobals
	end

	local function applyEnvironmentGlobals(targetEnvironment)
		local values = composeSandboxValues(targetEnvironment, true)
		local nextInstalledKeys = {}

		for key in pairs(values) do
			nextInstalledKeys[key] = true
		end

		for key in pairs(sandboxGlobals) do
			if nextInstalledKeys[key] == nil then
				sandboxGlobals[key] = nil

				if installedGlobalsSnapshot ~= nil and installedGlobalPresence[key] then
					baseGlobals[key] = nil
				end
			end
		end

		for key, value in pairs(values) do
			sandboxGlobals[key] = value

			if installedGlobalsSnapshot ~= nil then
				if not installedGlobalPresence[key] then
					installedGlobalsSnapshot[key] = baseGlobals[key]
					installedGlobalPresence[key] = true
				end

				baseGlobals[key] = value
			end
		end

		installedKeys = nextInstalledKeys
	end

	function controller:refreshActive()
		applyEnvironmentGlobals(fake.getEnvironment())
	end

	function controller:installEnvironment(targetEnvironment)
		local currentEnvironment = fake.getEnvironment()

		if currentEnvironment == targetEnvironment then
			return
		end

		if currentEnvironment ~= nil then
			captureCustomGlobals(currentEnvironment)
		end

		Environment.setActiveEnvironment(targetEnvironment)
		applyEnvironmentGlobals(targetEnvironment)
	end

	function controller:uninstallEnvironment(targetEnvironment)
		if targetEnvironment._isBaseEnvironment then
			error("Cannot uninstall the base environment", 2)
		end

		local currentEnvironment = fake.getEnvironment()

		if currentEnvironment ~= targetEnvironment then
			error("Cannot uninstall an environment that is not active", 2)
		end

		captureCustomGlobals(targetEnvironment)
		self:installEnvironment(environment)
	end

	environment._installController = controller
	environment._isBaseEnvironment = true
	Environment.setActiveInstallController(controller)
	Environment.setActiveEnvironment(environment)

	local function createInstance(name: string, className: string, parent)
		local instance = environment.Instance.new(className)
		instance.Name = name

		if parent ~= nil then
			instance.Parent = parent
		end

		return instance
	end

	local function createChild(parent, name: string, className: string?)
		local child = rawget(parent, "_childrenByName")[name]

		if child == nil then
			local existing = rawget(parent, name)

			if type(existing) == "table" and existing._isFakeRobloxInstance then
				child = existing
			end
		end

		if child ~= nil then
			return child
		end

		child = createInstance(name, className or "Folder", parent)
		child._childResolver = parent._childResolver
		child._moduleTree = if parent._moduleTree ~= nil then parent._moduleTree.children[name] else nil

		return child
	end

	local function ensureService(serviceName: string)
		return environment:getService(serviceName)
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
			local moduleName = entryName:gsub("%.luau?$", "")

			if moduleName == "init" and fs.isFile(entryPath) then
				tree.className = "ModuleScript"
			else
				local childTree = tree.children[moduleName]

				if childTree == nil then
					childTree = {
						children = {},
					}
					tree.children[moduleName] = childTree
				end

				if fs.isDir(entryPath) then
					local nestedTree = buildModuleTree(entryPath)
					childTree.className = nestedTree.className or "Folder"
					childTree.children = nestedTree.children
				elseif fs.isFile(entryPath) and entryName:match("%.luau?$") then
					childTree.className = "ModuleScript"
				end
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

	local function ensureSpecialMountNodes(mountPath: string)
		local specialMount = specialMounts[mountPath]

		if specialMount == nil then
			return nil
		end

		local nodes = {}

		for _, specialNode in ipairs(specialMount.nodes) do
			local node = ensureService(specialNode.serviceName)

			for _, segment in ipairs(specialNode.path) do
				node = createChild(node, segment)
			end

			node.ClassName = specialNode.className
			table.insert(nodes, node)
		end

		return nodes
	end

	local function ensureMountNode(mountPath: string)
		local segments = paths.splitPath(mountPath)
		assert(#segments > 0, "mount path must not be empty")

		local firstSegment = table.remove(segments, 1)
		local specialNodes = ensureSpecialMountNodes(mountPath)

		if specialNodes ~= nil then
			return specialNodes[1], specialNodes
		end

		local node = ensureService(firstSegment)

		for _, segment in ipairs(segments) do
			node = createChild(node, segment)
		end

		return node
	end

	local function mountService(mountPath: string, moduleRoot: string)
		local primaryNode, allNodes = ensureMountNode(mountPath)

		if allNodes ~= nil then
			local primaryMount = nil

			for _, node in ipairs(allNodes) do
				local mount = registerMount(node, moduleRoot)

				if primaryMount == nil then
					primaryMount = mount
				end
			end

			return primaryMount
		end

		return registerMount(primaryNode, moduleRoot)
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
		if path:sub(1, 6) == "@self/" then
			local requireBasePath = sandboxGlobals.__currentRequireBasePath
			assert(requireBasePath ~= nil, "Self alias require used without a current module: " .. path)
			return paths.normalizeFilesystemPath(paths.pathJoin(requireBasePath, path:sub(7)))
		end

		if path == "@self" then
			local requireBasePath = sandboxGlobals.__currentRequireBasePath
			assert(requireBasePath ~= nil, "Self alias require used without a current module: " .. path)
			return paths.normalizeFilesystemPath(requireBasePath)
		end

		if path:sub(1, 1) == "." then
			local requireBasePath = sandboxGlobals.__currentRequireBasePath

			if requireBasePath ~= nil then
				return paths.normalizeFilesystemPath(paths.pathJoin(requireBasePath, path))
			end

			local currentFilePath = sandboxGlobals.__currentFilePath

			if currentFilePath ~= nil then
				return paths.normalizeFilesystemPath(paths.pathJoin(paths.dirname(currentFilePath), path))
			end

			error("Relative require used without a current script: " .. path)
		end

		return paths.normalizeRequirePath(path)
	end

	local function loadFileModule(modulePath: string, scriptInstance, ...)
		modulePath = paths.normalizeFilesystemPath(modulePath)

		local cached = fileModuleCache[modulePath]

		if cached ~= nil then
			return cached
		end

		local sourceFilePath = paths.resolveExistingSourceFile(modulePath)
		assert(sourceFilePath ~= nil, `missing module source for {modulePath}`)

		local moduleSource = fs.readFile(sourceFilePath)
		local moduleChunk, moduleCompileErr = loadstring(moduleSource, "@" .. modulePath)

		if not moduleChunk then
			error(moduleCompileErr, 0)
		end

		setfenv(moduleChunk, sandboxGlobals)

		local oldScript = sandboxGlobals.script
		local oldCurrentFilePath = sandboxGlobals.__currentFilePath
		local oldCurrentRequireBasePath = sandboxGlobals.__currentRequireBasePath
		local requireBasePath = paths.dirname(sourceFilePath)

		sandboxGlobals.script = scriptInstance
		sandboxGlobals.__currentFilePath = modulePath
		sandboxGlobals.__currentRequireBasePath = requireBasePath

		local packedArgs = table.pack(...)
		local moduleOk, moduleResult = xpcall(function()
			return moduleChunk(unpack(packedArgs, 1, packedArgs.n))
		end, traceback)

		sandboxGlobals.script = oldScript
		sandboxGlobals.__currentFilePath = oldCurrentFilePath
		sandboxGlobals.__currentRequireBasePath = oldCurrentRequireBasePath

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
		elseif modulePath:sub(1, 6) ~= "@lune/" then
			error(`Unable to resolve module path "{modulePath}"`, 2)
		end

		local ok, result = pcall(loader, loadTarget, scriptInstance)

		if not ok then
			error(result, 2)
		end

		return result
	end

	function robloxRequire(target)
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
		if installedGlobalsSnapshot ~= nil then
			return
		end

		Environment.setActiveInstallController(controller)
		Environment.setActiveEnvironment(environment)
		applyEnvironmentGlobals(environment)

		installedGlobalsSnapshot = {}

		for key in pairs(installedKeys) do
			installedGlobalsSnapshot[key] = baseGlobals[key]
			installedGlobalPresence[key] = true
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
		installedGlobalPresence = {}
		installedKeys = {}
		Environment.setActiveEnvironment(nil)
		Environment.setActiveInstallController(nil)
	end

	return {
		environment = environment,
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
