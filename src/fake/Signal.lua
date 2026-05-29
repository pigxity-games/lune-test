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

function RBXScriptSignal:Fire(...)
	local snapshot = table.clone(self._connections)

	for _, connection in ipairs(snapshot) do
		if connection.Connected then
			connection._listener(...)
		end
	end
end

function RBXScriptSignal:DisconnectAll()
	local snapshot = table.clone(self._connections)

	for _, connection in ipairs(snapshot) do
		connection:Disconnect()
	end
end

function RBXScriptSignal:GetConnectionCount()
	return #self._connections
end

function RBXScriptSignal:GetDebugName()
	return self._name
end

RBXScriptSignal.RBXScriptConnection = RBXScriptConnection

return RBXScriptSignal
