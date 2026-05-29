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

local activeEnvironment = nil
local activeInstallController = nil

local defaultAvailableServices = {
	CollectionService = true,
	MemoryStoreService = true,
	Players = true,
	ReplicatedStorage = true,
	RunService = true,
	ServerScriptService = true,
	StarterPlayer = true,
	Workspace = true,
}

local builtInServiceNames = {
	"CollectionService",
	"MemoryStoreService",
	"Players",
	"ReplicatedStorage",
	"RunService",
	"ServerScriptService",
	"StarterPlayer",
	"Workspace",
}

local defaultEnum = {
	SortDirection = {
		Ascending = "Ascending",
		Descending = "Descending",
	},
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

local function cloneNestedTable(input)
	if type(input) ~= "table" or input._isFakeRobloxInstance then
		return input
	end

	local copy = {}

	for key, value in pairs(input) do
		copy[key] = cloneNestedTable(value)
	end

	return copy
end

local function freezeTableDeep(input)
	if table.freeze == nil or type(input) ~= "table" or table.isfrozen(input) then
		return input
	end

	for _, value in pairs(input) do
		if type(value) == "table" and not value._isFakeRobloxInstance then
			freezeTableDeep(value)
		end
	end

	table.freeze(input)
	return input
end

local function cloneAvailableServices(availableServices, serviceOverrides)
	local merged = {}

	for serviceName, enabled in pairs(defaultAvailableServices) do
		merged[serviceName] = enabled
	end

	for serviceName, enabled in pairs(availableServices or {}) do
		assert(
			type(serviceName) == "string" and type(enabled) == "boolean",
			'availableServices must be a set of serviceName = true/false entries'
		)
		merged[serviceName] = enabled == true
	end

	for serviceName in pairs(serviceOverrides or {}) do
		merged[serviceName] = true
	end

	return merged
end

local function clonePublicConfig(config)
	return {
		availableServices = cloneAvailableServices(config.availableServices, config.serviceOverrides),
		serviceOverrides = cloneNestedTable(config.serviceOverrides),
		datamodel = cloneNestedTable(config.datamodel),
		globals = cloneNestedTable(config.globals),
		isStudio = config.isStudio,
		isServer = config.isServer,
		isClient = config.isClient,
		privateServerId = config.privateServerId,
		privateServerOwnerId = config.privateServerOwnerId,
	}
end

local function rebuildFrozenPublicConfig(config)
	return freezeTableDeep(clonePublicConfig(config))
end

local function listSet(set)
	local values = {}

	for value, enabled in pairs(set) do
		if enabled then
			table.insert(values, value)
		end
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
			presentSet = {},
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

function Environment.new(config)
	config = config or {}

	local self = setmetatable({
		_initialConfig = cloneNestedTable(config),
		_configState = {
			availableServices = cloneAvailableServices(config.availableServices, config.serviceOverrides),
			serviceOverrides = cloneNestedTable(config.serviceOverrides) or {},
			datamodel = cloneNestedTable(config.datamodel) or {},
			globals = cloneNestedTable(config.globals) or {},
			isStudio = if config.isStudio ~= nil then config.isStudio else true,
			isServer = if config.isServer ~= nil then config.isServer else true,
			isClient = if config.isClient ~= nil then config.isClient else true,
			privateServerId = config.privateServerId or "",
			privateServerOwnerId = config.privateServerOwnerId or 0,
		},
		_flags = {
			isStudio = if config.isStudio ~= nil then config.isStudio else true,
			isServer = if config.isServer ~= nil then config.isServer else true,
			isClient = if config.isClient ~= nil then config.isClient else true,
			privateServerId = config.privateServerId or "",
			privateServerOwnerId = config.privateServerOwnerId or 0,
		},
		_availableServices = cloneAvailableServices(config.availableServices, config.serviceOverrides),
		_availableInstanceTypes = normalizeSet(config.availableInstanceTypes, ClassData.list()),
		_signalRegistry = {},
		_services = {},
		_players = {},
		_playerByUserId = {},
		_nextUserId = config.nextUserId or 1,
		_tagState = {},
		_remoteTraffic = {},
		_remoteInstances = {},
		_memoryStoreMaps = {},
		_memoryStoreQueues = {},
		_persistenceAdapters = shallowClone(config.persistenceAdapters),
		_serviceOverrides = cloneNestedTable(config.serviceOverrides) or {},
		_customGlobals = {},
		_installController = activeInstallController,
		_isBaseEnvironment = false,
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
			return self:_newInstance(className, parent, false)
		end,
	}

	self.game = self:_newInstance("DataModel", nil, true)
	self.game.Name = "game"
	self.game.GetService = function(_, serviceName: string)
		if not self:_isServiceEnabled(serviceName) then
			return nil
		end

		return self:getService(serviceName)
	end
	self.game.FindService = function(_, serviceName: string)
		return self._services[serviceName]
	end
	self:_syncDataModelProperties()
	self:_applyConfiguredDataModelProperties()
	self.config = rebuildFrozenPublicConfig(self._configState)

	for _, serviceName in ipairs(builtInServiceNames) do
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

function Environment.getActiveEnvironment()
	return activeEnvironment
end

function Environment.setActiveEnvironment(environment)
	activeEnvironment = environment
end

function Environment.setActiveInstallController(controller)
	activeInstallController = controller
end

function Environment:_isServiceEnabled(serviceName: string): boolean
	return self._availableServices[serviceName] == true or self._serviceOverrides[serviceName] ~= nil
end

function Environment:_syncDataModelProperties()
	self.game.PrivateServerId = self._flags.privateServerId
	self.game.PrivateServerOwnerId = self._flags.privateServerOwnerId
end

function Environment:_applyConfiguredDataModelProperties()
	for key, value in pairs(self._configState.datamodel) do
		self.game[key] = value
	end
end

function Environment:_updatePublicConfig()
	self.config = rebuildFrozenPublicConfig(self._configState)
end

function Environment:_isInDataModel(instance): boolean
	local cursor = instance

	while cursor ~= nil do
		if cursor == self.game then
			return true
		end

		cursor = cursor.Parent
	end

	return false
end

function Environment:_setTaggedInstancePresence(state, instance, isPresent: boolean)
	local wasPresent = state.presentSet[instance] == true

	if wasPresent == isPresent then
		return
	end

	state.presentSet[instance] = if isPresent then true else nil

	if isPresent then
		if state.addedSignal ~= nil then
			state.addedSignal:Fire(instance)
		end
	else
		if state.removedSignal ~= nil then
			state.removedSignal:Fire(instance)
		end
	end
end

function Environment:_refreshTaggedInstancePresence(instance)
	local tags = instance._collectionTags

	if tags == nil then
		return
	end

	local isPresent = self:_isInDataModel(instance)

	for tag in pairs(tags) do
		local state = ensureTagState(self._tagState, tag)
		self:_setTaggedInstancePresence(state, instance, isPresent)
	end
end

function Environment:_newInstance(className: string, parent, allowNonCreatable: boolean?)
	local allowedClassNames = self._availableInstanceTypes

	if allowNonCreatable and not ClassData.isCreatable(className) then
		allowedClassNames = shallowClone(self._availableInstanceTypes)
		allowedClassNames.__allowNonCreatable = true
	end

	local instance = InstanceModule.new(className, parent, {
		runtime = self,
		allowedClassNames = allowedClassNames,
		signalRegistry = self._signalRegistry,
	})

	self:_configureInstance(instance)
	instance.AncestryChanged:Connect(function(changedInstance)
		self:_onInstanceAncestryChanged(changedInstance)
	end)

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
		instance.InvokeServer = function(remote, ...)
			local player = self._localPlayer
			assert(player ~= nil, `RemoteFunction "{remote.Name}" cannot InvokeServer without a LocalPlayer`)
			return self:_invokeServer(remote, player, ...)
		end
		instance.InvokeClient = function(remote, player, ...)
			return self:_invokeClient(remote, player, ...)
		end
		table.insert(self._remoteInstances, instance)
		return
	end
end

function Environment:_logRemoteTraffic(kind: string, remote, player, args)
	table.insert(self._remoteTraffic, {
		kind = kind,
		remoteName = remote.Name,
		playerName = if player ~= nil then player.Name else nil,
		args = cloneArray(args),
	})
end

function Environment:_sanitizeRemoteValue(value, targetPlayer)
	if type(value) == "function" or type(value) == "thread" then
		return nil
	end

	if type(value) == "table" and value._isFakeRobloxInstance then
		if not self:_isInDataModel(value) then
			return nil
		end

		return value
	end

	return value
end

function Environment:_sanitizeRemoteArgs(targetPlayer, args)
	local sanitized = {}

	for index, value in ipairs(args) do
		sanitized[index] = self:_sanitizeRemoteValue(value, targetPlayer)
	end

	return sanitized
end

function Environment:_fireServerEvent(remote, player, ...)
	local args = self:_sanitizeRemoteArgs(nil, { ... })
	self:_logRemoteTraffic("FireServer", remote, player, args)
	remote.OnServerEvent:Fire(player, unpack(args))
end

function Environment:_fireClientEvent(remote, player, ...)
	assert(player ~= nil, `RemoteEvent "{remote.Name}" requires a player for FireClient`)
	local args = self:_sanitizeRemoteArgs(player, { ... })
	self:_logRemoteTraffic("FireClient", remote, player, args)
	remote.OnClientEvent:FireForPlayer(player, unpack(args))

	if player == self._localPlayer then
		remote.OnClientEvent:Fire(unpack(args))
	end
end

function Environment:_invokeServer(remote, player, ...)
	local args = self:_sanitizeRemoteArgs(nil, { ... })
	self:_logRemoteTraffic("InvokeServer", remote, player, args)
	assert(remote.OnServerInvoke ~= nil, `RemoteFunction "{remote.Name}" has no OnServerInvoke handler`)
	return remote.OnServerInvoke(player, unpack(args))
end

function Environment:_invokeClient(remote, player, ...)
	assert(player ~= nil, `RemoteFunction "{remote.Name}" requires a player for InvokeClient`)
	local args = self:_sanitizeRemoteArgs(player, { ... })
	self:_logRemoteTraffic("InvokeClient", remote, player, args)
	local handler = if player == self._localPlayer then remote.OnClientInvoke else nil

	assert(handler ~= nil, `RemoteFunction "{remote.Name}" has no OnClientInvoke handler for {player.Name}`)

	return handler(unpack(args))
end

function Environment:_createRunService()
	local service = self:_newInstance("RunService", self.game, true)
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
	local service = self:_newInstance("CollectionService", self.game, true)
	service.Name = "CollectionService"
	rawset(service, "AddTag", function(_, instance, tag: string)
		local state = ensureTagState(self._tagState, tag)

		if state.set[instance] then
			return
		end

		state.set[instance] = true
		table.insert(state.instances, instance)
		instance._collectionTags = instance._collectionTags or {}
		instance._collectionTags[tag] = true
		self:_setTaggedInstancePresence(state, instance, self:_isInDataModel(instance))
	end)
	rawset(service, "RemoveTag", function(_, instance, tag: string)
		local state = self._tagState[tag]

		if state == nil or not state.set[instance] then
			return
		end

		state.set[instance] = nil
		removeArrayValue(state.instances, instance)

		if instance._collectionTags ~= nil then
			instance._collectionTags[tag] = nil
		end
		self:_setTaggedInstancePresence(state, instance, false)
	end)
	rawset(service, "HasTag", function(_, instance, tag: string)
		local state = self._tagState[tag]
		return state ~= nil and state.set[instance] == true
	end)
	service.GetTagged = function(_, tag: string)
		local state = self._tagState[tag]

		if state == nil then
			return {}
		end

		local tagged = {}

		for _, instance in ipairs(state.instances) do
			if not instance._destroyed and state.presentSet[instance] then
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
		state.removedSignal = state.removedSignal
			or Signal.new(`CollectionService[{tag}].Removed`, self._signalRegistry)
		return state.removedSignal
	end
	return service
end

function Environment:_createPlayersService()
	local service = self:_newInstance("Players", self.game, true)
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
	local service = self:_newInstance("MemoryStoreService", self.game, true)
	service.Name = "MemoryStoreService"
	service.GetSortedMap = function(_, name: string)
		local map = self._memoryStoreMaps[name]

		if map ~= nil then
			return map
		end

		local state = {}

		local function getLiveEntry(key: string)
			local entry = state[key]

			if entry == nil then
				return nil
			end

			if entry.expiresAt ~= nil and entry.expiresAt <= self.scheduler:now() then
				state[key] = nil
				return nil
			end

			return entry
		end

		map = {
			GetAsync = function(_, key: string)
				local entry = getLiveEntry(key)
				if entry == nil then
					return nil
				end

				return entry.value, entry.sortKey
			end,
			SetAsync = function(_, key: string, value, expirationSeconds: number?, sortKey)
				state[key] = {
					value = value,
					sortKey = sortKey,
					expiresAt = if expirationSeconds ~= nil then self.scheduler:now() + expirationSeconds else nil,
				}
			end,
			UpdateAsync = function(_, key: string, transform, expirationSeconds: number?)
				local oldValue, oldSortKey = map:GetAsync(key)
				local oldEntry = getLiveEntry(key)
				local newValue, newSortKey = transform(oldValue, oldSortKey)

				if newValue == nil then
					return nil
				end

				state[key] = {
					value = newValue,
					sortKey = if newSortKey ~= nil
						then newSortKey
						else if oldEntry ~= nil then oldEntry.sortKey else nil,
					expiresAt = if expirationSeconds ~= nil
						then self.scheduler:now() + expirationSeconds
						else if oldEntry ~= nil then oldEntry.expiresAt else nil,
				}

				return newValue, state[key].sortKey
			end,
			RemoveAsync = function(_, key: string)
				state[key] = nil
			end,
			GetRangeAsync = function(_, sortDirection, count: number?)
				local items = {}

				for key in pairs(state) do
					local entry = getLiveEntry(key)

					if entry ~= nil then
						table.insert(items, {
							key = key,
							value = entry.value,
							sortKey = entry.sortKey,
						})
					end
				end

				table.sort(items, function(a, b)
					if a.sortKey ~= nil or b.sortKey ~= nil then
						if a.sortKey == nil then
							return false
						end

						if b.sortKey == nil then
							return true
						end

						if a.sortKey ~= b.sortKey then
							if sortDirection == defaultEnum.SortDirection.Descending then
								return a.sortKey > b.sortKey
							end

							return a.sortKey < b.sortKey
						end
					end

					if sortDirection == defaultEnum.SortDirection.Descending then
						return a.key > b.key
					end

					return a.key < b.key
				end)

				local limit = math.max(count or #items, 0)
				local ranged = {}

				for index = 1, math.min(limit, #items) do
					ranged[index] = items[index]
				end

				return ranged
			end,
			ListItemsAsync = function()
				local items = {}

				for key in pairs(state) do
					local entry = getLiveEntry(key)

					if entry == nil then
						continue
					end

					table.insert(items, {
						key = key,
						value = entry.value,
						sortKey = entry.sortKey,
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
	service.GetQueue = function(_, name: string, invisibilityTimeoutSeconds: number?)
		local queue = self._memoryStoreQueues[name]

		if queue ~= nil then
			return queue
		end

		local items = {}
		local nextReservationId = 0
		local nextSequenceNumber = 0

		local visibilityTimeout = invisibilityTimeoutSeconds or 30

		local function refreshReservation(item)
			if
				item.reservationId ~= nil
				and item.reservationExpiresAt ~= nil
				and item.reservationExpiresAt <= self.scheduler:now()
			then
				item.reservationId = nil
				item.reservationExpiresAt = nil
			end
		end

		local function isVisible(item)
			refreshReservation(item)
			return item.reservationId == nil
		end

		local function getLiveItems()
			local liveItems = {}

			for index = #items, 1, -1 do
				local item = items[index]

				if item.expiresAt ~= nil and item.expiresAt <= self.scheduler:now() then
					table.remove(items, index)
				else
					refreshReservation(item)
					table.insert(liveItems, 1, item)
				end
			end

			return liveItems
		end

		queue = {
			AddAsync = function(_, value, expirationSeconds: number?, priority: number?)
				nextSequenceNumber += 1
				table.insert(items, {
					value = value,
					reservationId = nil,
					priority = priority or 0,
					sequenceNumber = nextSequenceNumber,
					expiresAt = if expirationSeconds ~= nil then self.scheduler:now() + expirationSeconds else nil,
				})
			end,
			ReadAsync = function(_, count: number?, allOrNothing, _waitTimeout)
				local take = math.max(count or 1, 0)
				local selectedItems = {}
				local liveItems = getLiveItems()

				table.sort(liveItems, function(a, b)
					if a.priority ~= b.priority then
						return a.priority > b.priority
					end

					return a.sequenceNumber < b.sequenceNumber
				end)

				for _, item in ipairs(liveItems) do
					if isVisible(item) then
						table.insert(selectedItems, item)

						if #selectedItems >= take then
							break
						end
					end
				end

				if allOrNothing and #selectedItems < take then
					return {}, nil
				end

				nextReservationId += 1
				local reservationId = `queue-{name}-{nextReservationId}`
				local values = {}

				for index, item in ipairs(selectedItems) do
					item.reservationId = reservationId
					item.reservationExpiresAt = self.scheduler:now() + visibilityTimeout
					values[index] = item.value
				end

				return values, reservationId
			end,
			RemoveAsync = function(_, reservationId: string)
				getLiveItems()

				for index = #items, 1, -1 do
					if items[index].reservationId == reservationId then
						table.remove(items, index)
					end
				end
			end,
			GetSizeAsync = function(_, excludeInvisible: boolean?)
				local liveItems = getLiveItems()

				if not excludeInvisible then
					return #liveItems
				end

				local visibleCount = 0

				for _, item in ipairs(liveItems) do
					if isVisible(item) then
						visibleCount += 1
					end
				end

				return visibleCount
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

function Environment:_createGenericService(serviceName: string)
	if ClassData.isSupported(serviceName) then
		local service = self:_newInstance(serviceName, self.game, true)
		service.Name = serviceName
		return service
	end

	return {
		Name = serviceName,
		ClassName = serviceName,
	}
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

	if not self:_isServiceEnabled(serviceName) then
		return nil
	end

	if service ~= nil then
		return service
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
		Enum = defaultEnum,
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
		if self:_isServiceEnabled(serviceName) then
			globals[serviceName] = self:getService(serviceName)
		end
	end

	if self._localPlayer ~= nil then
		globals.LocalPlayer = self._localPlayer
	end

	if self._services.Workspace ~= nil and self:_isServiceEnabled("Workspace") then
		globals.workspace = self._services.Workspace
	end

	for key, value in pairs(self._configState.globals) do
		if globals[key] == nil then
			globals[key] = value
		end
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

function Environment:_onInstanceAncestryChanged(instance)
	self:_refreshTaggedInstancePresence(instance)
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
	local runHooks = config.runHooks ~= false

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

	local playerScripts = self:_newInstance("PlayerScripts", player, true)
	playerScripts.Name = "PlayerScripts"

	player.Parent = playersService

	table.insert(self._players, player)
	self._playerByUserId[player.UserId] = player
	if runHooks then
		playersService.PlayerAdded:Fire(player)
	end

	if config.localPlayer then
		self:assignLocalPlayer(player)
	end

	if config.createCharacter then
		self:replaceCharacter(player, config.character, runHooks)
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

function Environment:replaceCharacter(player, characterConfig, runHooks: boolean?)
	if runHooks == nil then
		runHooks = true
	end

	if player.Character ~= nil then
		if runHooks then
			player.CharacterRemoving:Fire(player.Character)
		end
		player.Character:Destroy()
	end

	local character

	if type(characterConfig) == "table" and characterConfig._isFakeRobloxInstance then
		character = characterConfig
	else
		character = self:_newInstance("Model")
		character.Name = if type(characterConfig) == "table" and characterConfig.name ~= nil
			then characterConfig.name
			else player.Name
	end

	character.Parent = self:getService("Workspace")
	player.Character = character

	if runHooks then
		player.CharacterAdded:Fire(character)
	end

	return character
end

function Environment:overrideService(serviceName: string, override)
	self._serviceOverrides[serviceName] = override
	self._configState.serviceOverrides[serviceName] = cloneNestedTable(override)
	self._availableServices[serviceName] = true
	self._configState.availableServices[serviceName] = true

	if self._services[serviceName] ~= nil then
		self._services[serviceName] = self:_applyServiceOverride(serviceName, self._services[serviceName])
	end

	self:_updatePublicConfig()
	self:_refreshGlobals()

	if activeEnvironment == self and self._installController ~= nil and self._installController.refreshActive ~= nil then
		self._installController:refreshActive()
	end
end

function Environment:configure(config)
	config = config or {}

	for key, value in pairs(config) do
		if self._flags[key] ~= nil then
			self._flags[key] = value
			self._configState[key] = value
		end
	end

	if config.availableServices ~= nil then
		for serviceName, enabled in pairs(config.availableServices) do
			assert(
				type(serviceName) == "string" and type(enabled) == "boolean",
				'availableServices must be a set of serviceName = true/false entries'
			)
			self._availableServices[serviceName] = enabled == true
			self._configState.availableServices[serviceName] = enabled == true
		end
	end

	if config.serviceOverrides ~= nil then
		for serviceName, override in pairs(config.serviceOverrides) do
			self._serviceOverrides[serviceName] = cloneNestedTable(override)
			self._configState.serviceOverrides[serviceName] = cloneNestedTable(override)
			self._availableServices[serviceName] = true
			self._configState.availableServices[serviceName] = true
		end
	end

	if config.datamodel ~= nil then
		for key, value in pairs(config.datamodel) do
			self._configState.datamodel[key] = value
			self.game[key] = value
		end
	end

	if config.globals ~= nil then
		for key, value in pairs(config.globals) do
			self._configState.globals[key] = value
		end
	end

	self:_syncDataModelProperties()
	self:_updatePublicConfig()

	for serviceName, service in pairs(self._services) do
		if self:_isServiceEnabled(serviceName) then
			self._services[serviceName] = self:_applyServiceOverride(serviceName, service)
		end
	end

	self:_refreshGlobals()

	if activeEnvironment == self and self._installController ~= nil and self._installController.refreshActive ~= nil then
		self._installController:refreshActive()
	end
end

function Environment:reset(config)
	local controller = self._installController
	local isBaseEnvironment = self._isBaseEnvironment
	local customGlobals = self._customGlobals
	local nextConfig = config

	if nextConfig == nil then
		nextConfig = cloneNestedTable(self._initialConfig)
		nextConfig.availableServices = cloneNestedTable(self._configState.availableServices)
		nextConfig.serviceOverrides = cloneNestedTable(self._configState.serviceOverrides)
		nextConfig.datamodel = cloneNestedTable(self._configState.datamodel)
		nextConfig.globals = cloneNestedTable(self._configState.globals)
		nextConfig.isStudio = self._configState.isStudio
		nextConfig.isServer = self._configState.isServer
		nextConfig.isClient = self._configState.isClient
		nextConfig.privateServerId = self._configState.privateServerId
		nextConfig.privateServerOwnerId = self._configState.privateServerOwnerId
	end

	local replacement = Environment.new(nextConfig)

	for key in pairs(self) do
		self[key] = nil
	end

	for key, value in pairs(replacement) do
		self[key] = value
	end

	self._installController = controller
	self._isBaseEnvironment = isBaseEnvironment
	self._customGlobals = customGlobals

	if activeEnvironment == self and controller ~= nil and controller.refreshActive ~= nil then
		controller:refreshActive()
	end

	return self
end

function Environment:install()
	local controller = self._installController
	assert(controller ~= nil, "Environment install requires an active sandbox")
	controller:installEnvironment(self)
end

function Environment:uninstall()
	local controller = self._installController
	assert(controller ~= nil, "Environment uninstall requires an active sandbox")
	controller:uninstallEnvironment(self)
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
