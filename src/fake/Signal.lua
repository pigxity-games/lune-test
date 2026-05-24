local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end

	self.Connected = false
	self._signal:_disconnect(self)
end

function Signal.new(name: string?, registry)
	local self = setmetatable({
		_name = name or "Signal",
		_connections = {},
		_registry = registry,
	}, Signal)

	if registry ~= nil then
		registry[self] = true
	end

	return self
end

function Signal:_disconnect(connection)
	for index, candidate in ipairs(self._connections) do
		if candidate == connection then
			table.remove(self._connections, index)
			return
		end
	end
end

function Signal:Connect(listener)
	assert(type(listener) == "function", "Signal:Connect expects a function")

	local connection = setmetatable({
		Connected = true,
		_listener = listener,
		_signal = self,
	}, Connection)

	table.insert(self._connections, connection)

	return connection
end

function Signal:Fire(...)
	local snapshot = table.clone(self._connections)

	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			connection._listener(...)
		end
	end
end

function Signal:DisconnectAll()
	local snapshot = table.clone(self._connections)

	for _, connection in ipairs(snapshot) do
		connection:Disconnect()
	end
end

function Signal:GetConnectionCount()
	return #self._connections
end

function Signal:GetDebugName()
	return self._name
end

return Signal
