local BrickColor = require("./BrickColor")
local CFrame = require("./CFrame")
local ClassData = require("./ClassData")
local Color3 = require("./Color3")
local InstanceModule = require("./Instance")
local Random = require("./Random")
local Scheduler = require("./Scheduler")
local Signal = require("./Signal")
local UDim = require("./UDim")
local UDim2 = require("./UDim2")
local Vector2 = require("./Vector2")
local Vector3 = require("./Vector3")

local Environment = {}
Environment.__index = Environment

local defaultAvailableServices = {
	"CollectionService",
	"MemoryStoreService",
	"Players",
	"ReplicatedStorage",
	"RunService",
	"ServerScriptService",
	"StarterPlayer",
	"TeleportService",
	"Workspace",
}

local function cloneArray(items)
	local copy = {}

	for index, value in ipairs(items) do
		copy[index] = value
	end

	return copy
end

local function normalizeSet(values, fallback)
	if values == nil then
		values = fallback
	end

	local set = {}

	if #values > 0 then
		for _, value in ipairs(values) do
			set[value] = true
		end
	else
		for value, enabled in pairs(values) do
			if enabled then
				set[value] = true
			end
		end
	end

	return set
end

local function listSet(set)
	local values = {}

	for value in pairs(set) do
		table.insert(values, value)
	end

	table.sort(values)

	return values
end

local function joinValues(values)
	return table.concat(values, ", ")
end

local function shallowClone(input)
	local copy = {}

	for key, value in pairs(input or {}) do
		copy[key] = value
	end

	return copy
end

local function ensureTagState(tagState, tag: string)
	local state = tagState[tag]

	if state == nil then
		state = {
			instances = {},
			set = {},
			addedSignal = nil,
			removedSignal = nil,
		}
		tagState[tag] = state
	end

	return state
end

local function removeArrayValue(items, value)
	for index, candidate in ipairs(items) do
		if candidate == value then
			table.remove(items, index)
			return
		end
	end
end

local function createPlayersProxy(sharedPlayers, localPlayer)
	return setmetatable({}, {
		__index = function(_, key)
			if key == "LocalPlayer" then
				return localPlayer
			end

			local value = sharedPlayers[key]

			if type(value) == "function" then
				return function(_, ...)
					return value(sharedPlayers, ...)
				end
			end

			return value
		end,
		__newindex = function(_, key, value)
			if key == "LocalPlayer" then
				error("LocalPlayer is controlled by the fake environment", 2)
			end

			sharedPlayers[key] = value
		end,
	})
end

function Environment.new(config)
	config = config or {}

	local self = setmetatable({
		_initialConfig = shallowClone(config),
		_flags = {
			isStudio = if config.isStudio ~= nil then config.isStudio else true,
			isServer = if config.isServer ~= nil then config.isServer else true,
			isClient = if config.isClient ~= nil then config.isClient else true,
			privateServerId = config.privateServerId or "",
			privateServerOwnerId = config.privateServerOwnerId or 0,
			reservedServerAccessCode = config.reservedServerAccessCode or "",
			teleportData = config.teleportData,
		},
		_availableServices = normalizeSet(config.availableServices, defaultAvailableServices),
		_availableInstanceTypes = normalizeSet(config.availableInstanceTypes, ClassData.list()),
		_signalRegistry = {},
		_services = {},
		_players = {},
		_playerByUserId = {},
		_nextUserId = config.nextUserId or 1,
		_tagState = {},
		_remoteTraffic = {},
		_remoteInstances = {},
		_clients = {},
		_memoryStoreMaps = {},
		_memoryStoreQueues = {},
		_persistenceAdapters = shallowClone(config.persistenceAdapters),
		_serviceOverrides = shallowClone(config.serviceOverrides),
		_reservedServerCounter = 0,
	}, Environment)

	self.scheduler = Scheduler.new({
		runtime = self,
	})

	self.task = {
		spawn = function(callback, ...)
			return self.scheduler:spawn(callback, ...)
		end,
		defer = function(callback, ...)
			return self.scheduler:defer(callback, ...)
		end,
		delay = function(seconds: number, callback, ...)
			return self.scheduler:delay(seconds, callback, ...)
		end,
		wait = function(seconds: number?)
			return self.scheduler:wait(seconds)
		end,
		cancel = function(handle)
			return self.scheduler:cancel(handle)
		end,
	}

	self.Instance = {
		new = function(className: string, parent)
			return self:_newInstance(className, parent)
		end,
	}

	self.game = self:_newInstance("DataModel")
	self.game.Name = "game"
	self.game.GetService = function(_, serviceName: string)
		return self:getService(serviceName)
	end
	self.game.FindService = function(_, serviceName: string)
		return self._services[serviceName]
	end

	for _, serviceName in ipairs(defaultAvailableServices) do
		if self._availableServices[serviceName] then
			self:getService(serviceName)
		end
	end

	if config.activePlayers == nil then
		if self._availableServices.Players and self._flags.isClient then
			local player = self:addPlayer({
				name = config.localPlayerName or "LocalPlayer",
				userId = config.localPlayerUserId or 1,
				localPlayer = true,
				createCharacter = config.createDefaultCharacter,
			})
			self:assignLocalPlayer(player)
		end
	else
		for _, playerConfig in ipairs(config.activePlayers) do
			local player = self:addPlayer(playerConfig)

			if playerConfig.localPlayer then
				self:assignLocalPlayer(player)
			end
		end

		if self._flags.isClient and self._localPlayer == nil and self._players[1] ~= nil then
			self:assignLocalPlayer(self._players[1])
		end
	end

	self:_refreshGlobals()

	return self
end

function Environment:_newInstance(className: string, parent)
	local instance = InstanceModule.new(className, parent, {
		runtime = self,
		allowedClassNames = self._availableInstanceTypes,
		signalRegistry = self._signalRegistry,
	})

	self:_configureInstance(instance)

	return instance
end

function Environment:_configureInstance(instance)
	if instance:IsA("Player") then
		instance.CharacterAdded = Signal.new(`{instance.Name}.CharacterAdded`, self._signalRegistry)
		instance.CharacterRemoving = Signal.new(`{instance.Name}.CharacterRemoving`, self._signalRegistry)
		instance.LoadCharacter = function(player)
			return self:replaceCharacter(player)
		end
		return
	end

	if instance:IsA("RemoteEvent") then
		instance.OnServerEvent = Signal.new(`{instance.Name}.OnServerEvent`, self._signalRegistry)
		instance.OnClientEvent = Signal.new(`{instance.Name}.OnClientEvent`, self._signalRegistry)
		instance._clientEventSignals = {}
		instance.FireServer = function(remote, ...)
			local player = self._localPlayer
			assert(player ~= nil, `RemoteEvent "{remote.Name}" cannot FireServer without a LocalPlayer`)
			return self:_fireServerEvent(remote, player, ...)
		end
		instance.FireClient = function(remote, player, ...)
			return self:_fireClientEvent(remote, player, ...)
		end
		instance.FireAllClients = function(remote, ...)
			for _, player in ipairs(self._players) do
				self:_fireClientEvent(remote, player, ...)
			end
		end
		table.insert(self._remoteInstances, instance)
		return
	end

	if instance:IsA("RemoteFunction") then
		instance.OnServerInvoke = nil
		instance.OnClientInvoke = nil
		instance._clientInvokeHandlers = {}
		instance.InvokeServer = function(remote, ...)
			local player = self._localPlayer
			assert(player ~= nil, `RemoteFunction "{remote.Name}" cannot InvokeServer without a LocalPlayer`)
			return self:_invokeServer(remote, player, ...)
		end
		instance.InvokeClient = function(remote, player, ...)
			return self:_invokeClient(remote, player, ...)
		end
		table.insert(self._remoteInstances, instance)
	end
end

function Environment:_getRemoteClientEventSignal(remote, player)
	if player == nil then
		return remote.OnClientEvent
	end

	local signal = remote._clientEventSignals[player]

	if signal == nil then
		signal = Signal.new(`{remote.Name}.OnClientEvent[{player.Name}]`, self._signalRegistry)
		remote._clientEventSignals[player] = signal
	end

	return signal
end

function Environment:_logRemoteTraffic(kind: string, remote, player, args)
	table.insert(self._remoteTraffic, {
		kind = kind,
		remoteName = remote.Name,
		playerName = if player ~= nil then player.Name else nil,
		args = cloneArray(args),
	})
end

function Environment:_fireServerEvent(remote, player, ...)
	local args = { ... }
	self:_logRemoteTraffic("FireServer", remote, player, args)
	remote.OnServerEvent:Fire(player, ...)
end

function Environment:_fireClientEvent(remote, player, ...)
	assert(player ~= nil, `RemoteEvent "{remote.Name}" requires a player for FireClient`)
	local args = { ... }
	self:_logRemoteTraffic("FireClient", remote, player, args)
	self:_getRemoteClientEventSignal(remote, player):Fire(...)

	if player == self._localPlayer then
		remote.OnClientEvent:Fire(...)
	end
end

function Environment:_invokeServer(remote, player, ...)
	self:_logRemoteTraffic("InvokeServer", remote, player, { ... })
	assert(remote.OnServerInvoke ~= nil, `RemoteFunction "{remote.Name}" has no OnServerInvoke handler`)
	return remote.OnServerInvoke(player, ...)
end

function Environment:_invokeClient(remote, player, ...)
	assert(player ~= nil, `RemoteFunction "{remote.Name}" requires a player for InvokeClient`)
	self:_logRemoteTraffic("InvokeClient", remote, player, { ... })

	local handler = remote._clientInvokeHandlers[player]

	if handler == nil and player == self._localPlayer then
		handler = remote.OnClientInvoke
	end

	assert(handler ~= nil, `RemoteFunction "{remote.Name}" has no OnClientInvoke handler for {player.Name}`)

	return handler(...)
end

function Environment:_bindRemoteForPlayer(remote, player)
	return setmetatable({}, {
		__index = function(_, key)
			if remote:IsA("RemoteEvent") then
				if key == "FireServer" then
					return function(_, ...)
						return self:_fireServerEvent(remote, player, ...)
					end
				end

				if key == "OnClientEvent" then
					return self:_getRemoteClientEventSignal(remote, player)
				end
			end

			if remote:IsA("RemoteFunction") then
				if key == "InvokeServer" then
					return function(_, ...)
						return self:_invokeServer(remote, player, ...)
					end
				end

				if key == "OnClientInvoke" then
					return remote._clientInvokeHandlers[player]
				end
			end

			local value = remote[key]

			if type(value) == "function" then
				return function(_, ...)
					return value(remote, ...)
				end
			end

			return value
		end,
		__newindex = function(_, key, value)
			if remote:IsA("RemoteFunction") and key == "OnClientInvoke" then
				remote._clientInvokeHandlers[player] = value
				return
			end

			error(`Unsupported client remote field override: {key}`, 2)
		end,
	})
end

function Environment:_createRunService()
	local service = self:_newInstance("RunService", self.game)
	service.Name = "RunService"
	service.Heartbeat = Signal.new("RunService.Heartbeat", self._signalRegistry)
	service.Stepped = Signal.new("RunService.Stepped", self._signalRegistry)
	service.RenderStepped = Signal.new("RunService.RenderStepped", self._signalRegistry)
	service.IsStudio = function()
		return self._flags.isStudio
	end
	service.IsServer = function()
		return self._flags.isServer
	end
	service.IsClient = function()
		return self._flags.isClient
	end
	return service
end

function Environment:_createCollectionService()
	local service = self:_newInstance("CollectionService", self.game)
	service.Name = "CollectionService"
	service.AddTag = function(_, instance, tag: string)
		local state = ensureTagState(self._tagState, tag)

		if state.set[instance] then
			return
		end

		state.set[instance] = true
		table.insert(state.instances, instance)
		instance._collectionTags = instance._collectionTags or {}
		instance._collectionTags[tag] = true

		if state.addedSignal ~= nil then
			state.addedSignal:Fire(instance)
		end
	end
	service.RemoveTag = function(_, instance, tag: string)
		local state = self._tagState[tag]

		if state == nil or not state.set[instance] then
			return
		end

		state.set[instance] = nil
		removeArrayValue(state.instances, instance)

		if instance._collectionTags ~= nil then
			instance._collectionTags[tag] = nil
		end

		if state.removedSignal ~= nil then
			state.removedSignal:Fire(instance)
		end
	end
	service.HasTag = function(_, instance, tag: string)
		local state = self._tagState[tag]
		return state ~= nil and state.set[instance] == true
	end
	service.GetTagged = function(_, tag: string)
		local state = self._tagState[tag]

		if state == nil then
			return {}
		end

		local tagged = {}

		for _, instance in ipairs(state.instances) do
			if not instance._destroyed then
				table.insert(tagged, instance)
			end
		end

		return tagged
	end
	service.GetInstanceAddedSignal = function(_, tag: string)
		local state = ensureTagState(self._tagState, tag)
		state.addedSignal = state.addedSignal or Signal.new(`CollectionService[{tag}].Added`, self._signalRegistry)
		return state.addedSignal
	end
	service.GetInstanceRemovedSignal = function(_, tag: string)
		local state = ensureTagState(self._tagState, tag)
		state.removedSignal = state.removedSignal or Signal.new(`CollectionService[{tag}].Removed`, self._signalRegistry)
		return state.removedSignal
	end
	return service
end

function Environment:_createPlayersService()
	local service = self:_newInstance("Players", self.game)
	service.Name = "Players"
	service.PlayerAdded = Signal.new("Players.PlayerAdded", self._signalRegistry)
	service.PlayerRemoving = Signal.new("Players.PlayerRemoving", self._signalRegistry)
	service.LocalPlayer = nil
	service.GetPlayers = function()
		return cloneArray(self._players)
	end
	service.GetPlayerByUserId = function(_, userId: number)
		return self._playerByUserId[userId]
	end
	return service
end

function Environment:_createMemoryStoreService()
	local service = self:_newInstance("MemoryStoreService", self.game)
	service.Name = "MemoryStoreService"
	service.GetSortedMap = function(_, name: string)
		local map = self._memoryStoreMaps[name]

		if map ~= nil then
			return map
		end

		local state = {}

		map = {
			GetAsync = function(_, key: string)
				local entry = state[key]

				if entry == nil then
					return nil
				end

				if entry.expiresAt ~= nil and entry.expiresAt <= self.scheduler:now() then
					state[key] = nil
					return nil
				end

				return entry.value
			end,
			SetAsync = function(_, key: string, value, expirationSeconds: number?)
				state[key] = {
					value = value,
					expiresAt = if expirationSeconds ~= nil then self.scheduler:now() + expirationSeconds else nil,
				}
			end,
			UpdateAsync = function(_, key: string, transform, expirationSeconds: number?)
				local oldValue = map:GetAsync(key)
				local oldEntry = state[key]
				local newValue = transform(oldValue)

				if newValue == nil then
					state[key] = nil
				else
					state[key] = {
						value = newValue,
						expiresAt = if expirationSeconds ~= nil
							then self.scheduler:now() + expirationSeconds
							else if oldEntry ~= nil then oldEntry.expiresAt else nil,
					}
				end

				return newValue
			end,
			RemoveAsync = function(_, key: string)
				state[key] = nil
			end,
			ListItemsAsync = function()
				local items = {}

				for key in pairs(state) do
					table.insert(items, {
						key = key,
						value = map:GetAsync(key),
					})
				end

				table.sort(items, function(a, b)
					return a.key < b.key
				end)

				return items
			end,
		}

		self._memoryStoreMaps[name] = map
		return map
	end
	service.GetQueue = function(_, name: string)
		local queue = self._memoryStoreQueues[name]

		if queue ~= nil then
			return queue
		end

		local items = {}

		queue = {
			AddAsync = function(_, value)
				table.insert(items, value)
			end,
			ReadAsync = function(_, count: number?)
				local take = math.max(count or 1, 0)
				local result = {}

				for _ = 1, take do
					if #items == 0 then
						break
					end

					table.insert(result, table.remove(items, 1))
				end

				return result
			end,
			GetSizeAsync = function()
				return #items
			end,
		}

		self._memoryStoreQueues[name] = queue
		return queue
	end
	service.SetAdapter = function(_, name: string, adapter)
		self._persistenceAdapters[name] = adapter
	end
	service.GetAdapter = function(_, name: string)
		return self._persistenceAdapters[name]
	end
	return service
end

function Environment:_createTeleportService()
	local service = self:_newInstance("TeleportService", self.game)
	service.Name = "TeleportService"
	service.PrivateServerId = self._flags.privateServerId
	service.PrivateServerOwnerId = self._flags.privateServerOwnerId
	service.ReservedServerAccessCode = self._flags.reservedServerAccessCode
	service.TeleportAsync = function(_, placeId: number, players, options)
		local request = {
			placeId = placeId,
			players = cloneArray(players or {}),
			options = options or {},
		}

		table.insert(self._remoteTraffic, {
			kind = "TeleportAsync",
			placeId = placeId,
			playerName = if request.players[1] ~= nil then request.players[1].Name else nil,
			args = { options },
		})

		if options ~= nil and options.TeleportData ~= nil then
			for _, player in ipairs(request.players) do
				player._teleportData = options.TeleportData
			end
		end

		return request
	end
	service.ReserveServer = function(_, placeId: number)
		self._reservedServerCounter += 1
		local accessCode = `reserved-{placeId}-{self._reservedServerCounter}`
		self._flags.reservedServerAccessCode = accessCode
		service.ReservedServerAccessCode = accessCode
		return accessCode
	end
	service.GetLocalPlayerTeleportData = function()
		if self._localPlayer ~= nil and self._localPlayer._teleportData ~= nil then
			return self._localPlayer._teleportData
		end

		return self._flags.teleportData
	end
	return service
end

function Environment:_createGenericService(serviceName: string)
	local service = self:_newInstance(serviceName, self.game)
	service.Name = serviceName
	return service
end

function Environment:_instantiateService(serviceName: string)
	if serviceName == "RunService" then
		return self:_createRunService()
	end

	if serviceName == "CollectionService" then
		return self:_createCollectionService()
	end

	if serviceName == "Players" then
		return self:_createPlayersService()
	end

	if serviceName == "MemoryStoreService" then
		return self:_createMemoryStoreService()
	end

	if serviceName == "TeleportService" then
		return self:_createTeleportService()
	end

	return self:_createGenericService(serviceName)
end

function Environment:_applyServiceOverride(serviceName: string, service)
	local override = self._serviceOverrides[serviceName]

	if override == nil then
		return service
	end

	if type(override) == "function" then
		local replaced = override(self, service)
		return if replaced ~= nil then replaced else service
	end

	for key, value in pairs(override) do
		service[key] = value
	end

	return service
end

function Environment:getService(serviceName: string)
	local service = self._services[serviceName]

	if service ~= nil then
		return service
	end

	if not self._availableServices[serviceName] then
		error(
			`Unknown fake service "{serviceName}". Available services: {joinValues(listSet(self._availableServices))}`,
			2
		)
	end

	service = self:_instantiateService(serviceName)
	service = self:_applyServiceOverride(serviceName, service)
	self._services[serviceName] = service

	return service
end

function Environment:_refreshGlobals()
	local globals = {
		BrickColor = BrickColor,
		CFrame = CFrame,
		Color3 = Color3,
		Instance = self.Instance,
		Random = Random,
		UDim = UDim,
		UDim2 = UDim2,
		Vector2 = Vector2,
		Vector3 = Vector3,
		game = self.game,
		task = self.task,
	}

	for serviceName in pairs(self._services) do
		globals[serviceName] = self:getService(serviceName)
	end

	if self._localPlayer ~= nil then
		globals.LocalPlayer = self._localPlayer
	end

	if self._services.Workspace ~= nil then
		globals.workspace = self._services.Workspace
	end

	self.globals = globals
end

function Environment:_onSchedulerAdvanced(deltaTime: number)
	local runService = self._services.RunService

	if runService == nil then
		return
	end

	runService.Heartbeat:Fire(deltaTime)
	runService.Stepped:Fire(self.scheduler:now(), deltaTime)
	runService.RenderStepped:Fire(deltaTime)
end

function Environment:_onInstanceDestroying(instance)
	if instance._collectionTags ~= nil then
		local collectionService = self._services.CollectionService

		if collectionService ~= nil then
			local tags = {}

			for tag in pairs(instance._collectionTags) do
				table.insert(tags, tag)
			end

			for _, tag in ipairs(tags) do
				collectionService:RemoveTag(instance, tag)
			end
		end
	end
end

function Environment:_onInstanceDestroyed(instance)
	if not instance:IsA("Player") then
		return
	end

	removeArrayValue(self._players, instance)
	self._playerByUserId[instance.UserId] = nil
end

function Environment:addPlayer(config)
	config = config or {}

	local playersService = self:getService("Players")
	local player = config.instance or self:_newInstance("Player")
	player.Name = config.name or `Player{self._nextUserId}`

	if config.userId ~= nil then
		player.UserId = config.userId
		self._nextUserId = math.max(self._nextUserId, config.userId + 1)
	else
		player.UserId = self._nextUserId
		self._nextUserId += 1
	end

	local backpack = self:_newInstance("Backpack", player)
	backpack.Name = "Backpack"

	local playerScripts = self:_newInstance("PlayerScripts", player)
	playerScripts.Name = "PlayerScripts"

	player.Parent = playersService

	table.insert(self._players, player)
	self._playerByUserId[player.UserId] = player
	playersService.PlayerAdded:Fire(player)

	if config.localPlayer then
		self:assignLocalPlayer(player)
	end

	if config.createCharacter then
		self:replaceCharacter(player, config.character)
	end

	return player
end

function Environment:assignLocalPlayer(player)
	self._localPlayer = player
	self:getService("Players").LocalPlayer = player
	self:_refreshGlobals()
end

function Environment:getPlayers()
	return cloneArray(self._players)
end

function Environment:removePlayer(player)
	local playersService = self:getService("Players")
	playersService.PlayerRemoving:Fire(player)

	if player.Character ~= nil then
		player.CharacterRemoving:Fire(player.Character)
		player.Character:Destroy()
		player.Character = nil
	end

	if self._localPlayer == player then
		self._localPlayer = nil
		playersService.LocalPlayer = nil
	end

	player:Destroy()
	self:_refreshGlobals()
end

function Environment:replaceCharacter(player, characterConfig)
	if player.Character ~= nil then
		player.CharacterRemoving:Fire(player.Character)
		player.Character:Destroy()
	end

	local character

	if type(characterConfig) == "table" and characterConfig._isFakeRobloxInstance then
		character = characterConfig
	else
		character = self:_newInstance("Model")
		character.Name = if type(characterConfig) == "table" and characterConfig.name ~= nil then characterConfig.name else player.Name
	end

	character.Parent = self:getService("Workspace")
	player.Character = character
	player.CharacterAdded:Fire(character)

	return character
end

function Environment:spawnClient(config)
	config = config or {}

	local player = config.player or self:addPlayer({
		name = config.name,
		userId = config.userId,
		createCharacter = config.createCharacter,
	})

	local sharedPlayers = self:getService("Players")
	local playersProxy = createPlayersProxy(sharedPlayers, player)
	local gameProxy = {
		GetService = function(_, serviceName: string)
			if serviceName == "Players" then
				return playersProxy
			end

			return self:getService(serviceName)
		end,
	}

	local globals = {}

	for key, value in pairs(self.globals) do
		globals[key] = value
	end

	globals.game = gameProxy
	globals.LocalPlayer = player
	globals.Players = playersProxy

	local client = {
		LocalPlayer = player,
		game = gameProxy,
		globals = globals,
		bindRemote = function(_, remote)
			return self:_bindRemoteForPlayer(remote, player)
		end,
	}

	table.insert(self._clients, client)

	return client
end

function Environment:overrideService(serviceName: string, override)
	self._serviceOverrides[serviceName] = override

	if self._services[serviceName] ~= nil then
		self._services[serviceName] = self:_applyServiceOverride(serviceName, self._services[serviceName])
	end

	self:_refreshGlobals()
end

function Environment:configure(config)
	for key, value in pairs(config or {}) do
		if self._flags[key] ~= nil then
			self._flags[key] = value
		end
	end

	local teleportService = self._services.TeleportService

	if teleportService ~= nil then
		teleportService.PrivateServerId = self._flags.privateServerId
		teleportService.PrivateServerOwnerId = self._flags.privateServerOwnerId
		teleportService.ReservedServerAccessCode = self._flags.reservedServerAccessCode
	end
end

function Environment:reset(config)
	local replacement = Environment.new(config or self._initialConfig)

	for key in pairs(self) do
		self[key] = nil
	end

	for key, value in pairs(replacement) do
		self[key] = value
	end

	return self
end

function Environment:inspectTree(root)
	root = root or self.game

	local lines = {}

	local function visit(node, depth)
		table.insert(lines, string.rep("  ", depth) .. `{node.Name} <{node.ClassName}>`)

		for _, child in ipairs(node:GetChildren()) do
			visit(child, depth + 1)
		end
	end

	visit(root, 0)

	return table.concat(lines, "\n")
end

function Environment:inspectTasks()
	return self.scheduler:inspect()
end

function Environment:inspectSignals()
	local info = {}

	for signal in pairs(self._signalRegistry) do
		table.insert(info, {
			name = signal:GetDebugName(),
			connections = signal:GetConnectionCount(),
		})
	end

	table.sort(info, function(a, b)
		return a.name < b.name
	end)

	return info
end

function Environment:inspectRemoteTraffic()
	return cloneArray(self._remoteTraffic)
end

return Environment
