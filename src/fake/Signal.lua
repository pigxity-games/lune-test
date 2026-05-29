local RBXScriptSignal = {}
RBXScriptSignal.__index = RBXScriptSignal

local RBXScriptConnection = {}
RBXScriptConnection.__index = RBXScriptConnection

function RBXScriptConnection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false
	self._signal:_disconnect(self)
end

function RBXScriptSignal.new(name: string?, registry)
	local self = setmetatable({
		_name = name or "RBXScriptSignal",
		_connections = {},
		_playerConnections = {},
		_registry = registry,
	}, RBXScriptSignal)

	if registry ~= nil then
		registry[self] = true
	end

	return self
end

function RBXScriptSignal:_disconnect(connection)
	for index, candidate in ipairs(self._connections) do
		if candidate == connection then
			table.remove(self._connections, index)
			return
		end
	end

	for index, candidate in ipairs(self._playerConnections) do
		if candidate == connection then
			table.remove(self._playerConnections, index)
			return
		end
	end
end

function RBXScriptSignal:Connect(listener)
	assert(type(listener) == "function", "RBXScriptSignal:Connect expects a function")

	local connection = setmetatable({
		Connected = true,
		_listener = listener,
		_signal = self,
	}, RBXScriptConnection)

	table.insert(self._connections, connection)

	return connection
end

function RBXScriptSignal:ConnectPlayer(player, listener)
	assert(player ~= nil, "RBXScriptSignal:ConnectPlayer expects a player")
	assert(type(listener) == "function", "RBXScriptSignal:ConnectPlayer expects a function")

	local connection = setmetatable({
		Connected = true,
		_listener = listener,
		_player = player,
		_signal = self,
	}, RBXScriptConnection)

	table.insert(self._playerConnections, connection)

	return connection
end

function RBXScriptSignal:Fire(...)
	local snapshot = table.clone(self._connections)

	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			connection._listener(...)
		end
	end
end

function RBXScriptSignal:FireForPlayer(player, ...)
	local snapshot = table.clone(self._playerConnections)

	for _, connection in ipairs(snapshot) do
		if connection.Connected and connection._player == player then
			connection._listener(...)
		end
	end
end

function RBXScriptSignal:DisconnectAll()
	local snapshot = table.clone(self._connections)

	for _, connection in ipairs(snapshot) do
		connection:Disconnect()
	end

	snapshot = table.clone(self._playerConnections)

	for _, connection in ipairs(snapshot) do
		connection:Disconnect()
	end
end

function RBXScriptSignal:GetConnectionCount()
	return #self._connections + #self._playerConnections
end

function RBXScriptSignal:GetDebugName()
	return self._name
end

RBXScriptSignal.RBXScriptConnection = RBXScriptConnection

return RBXScriptSignal
