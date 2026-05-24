local CFrame = require("./CFrame")
local ClassData = require("./ClassData")
local Signal = require("./Signal")
local Vector3 = require("./Vector3")

local Instance = {}

local InstanceMethods = {}
local InstanceMetatable = {}

local function cloneArray(items)
	local copy = {}

	for index, value in ipairs(items) do
		copy[index] = value
	end

	return copy
end

local function joinNames(names)
	return table.concat(names, ", ")
end

local function updateNamedChildLookup(parent, childName: string)
	for _, child in ipairs(parent._children) do
		if child.Name == childName then
			parent._childrenByName[childName] = child
			return
		end
	end

	parent._childrenByName[childName] = nil
end

local function getSignal(self, name: string)
	local signals = rawget(self, "_signals")
	local signal = signals[name]

	if signal == nil then
		signal = Signal.new(`{rawget(self, "_name")}.{name}`, rawget(self, "_signalRegistry"))
		signals[name] = signal
	end

	return signal
end

local function firePropertyChanged(self, propertyName: string, value)
	local propertySignals = rawget(self, "_propertySignals")
	local propertySignal = propertySignals[propertyName]

	if propertySignal ~= nil then
		propertySignal:Fire(value)
	end

	if self:IsA("NumberValue") and propertyName == "Value" then
		getSignal(self, "Changed"):Fire(value)
	else
		getSignal(self, "Changed"):Fire(propertyName)
	end
end

local function setBasePartSpatialProperty(self, propertyName: string, value)
	local properties = rawget(self, "_properties")

	if propertyName == "Position" then
		properties.Position = value
		properties.CFrame = CFrame.new(value)
		firePropertyChanged(self, "Position", value)
		firePropertyChanged(self, "CFrame", properties.CFrame)
		return true
	end

	if propertyName == "CFrame" then
		properties.CFrame = value
		properties.Position = value.Position
		firePropertyChanged(self, "CFrame", value)
		firePropertyChanged(self, "Position", properties.Position)
		return true
	end

	return false
end

local function removeFromParent(parent, child)
	for index, candidate in ipairs(parent._children) do
		if candidate == child then
			table.remove(parent._children, index)
			break
		end
	end

	updateNamedChildLookup(parent, child.Name)
	getSignal(parent, "ChildRemoved"):Fire(child)
end

local function addToParent(parent, child)
	table.insert(parent._children, child)
	updateNamedChildLookup(parent, child.Name)
	getSignal(parent, "ChildAdded"):Fire(child)
end

local function assertSupportedClassName(className: string, allowedClassNames)
	if not ClassData.isSupported(className) then
		error(`Unsupported fake instance type "{className}". Available types: {joinNames(ClassData.list())}`, 3)
	end

	if allowedClassNames == nil or allowedClassNames[className] then
		return
	end

	local available = {}

	for allowedClassName in pairs(allowedClassNames) do
		table.insert(available, allowedClassName)
	end

	table.sort(available)

	error(`Fake instance type "{className}" is disabled in this environment. Enabled types: {joinNames(available)}`, 3)
end

local function setParent(self, newParent)
	local oldParent = rawget(self, "_parent")

	if oldParent == newParent then
		return
	end

	if newParent ~= nil then
		assert(
			type(newParent) == "table" and newParent._isFakeRobloxInstance,
			"Parent must be a fake Roblox instance or nil"
		)

		local cursor = newParent

		while cursor ~= nil do
			if cursor == self then
				error(`Cannot parent "{self.Name}" under one of its descendants`, 3)
			end

			cursor = cursor.Parent
		end
	end

	if oldParent ~= nil then
		removeFromParent(oldParent, self)
	end

	rawset(self, "_parent", newParent)

	if newParent ~= nil then
		addToParent(newParent, self)
	end

	getSignal(self, "AncestryChanged"):Fire(self, newParent)
end

local function setName(self, value)
	local oldName = rawget(self, "_name")

	if oldName == value then
		return
	end

	local parent = rawget(self, "_parent")

	rawset(self, "_name", value)

	if parent ~= nil then
		updateNamedChildLookup(parent, oldName)
		updateNamedChildLookup(parent, value)
	end

	firePropertyChanged(self, "Name", value)
end

local function setProperty(self, propertyName: string, value)
	if rawget(self, "_destroyed") then
		error(`Cannot set "{propertyName}" on destroyed instance "{rawget(self, "_name")}"`, 3)
	end

	if self:IsA("BasePart") and setBasePartSpatialProperty(self, propertyName, value) then
		return
	end

	local properties = rawget(self, "_properties")
	local propertyPresence = rawget(self, "_propertyPresence")
	local oldValue = if propertyPresence[propertyName] then properties[propertyName] else nil

	properties[propertyName] = value
	propertyPresence[propertyName] = true

	if oldValue ~= value then
		firePropertyChanged(self, propertyName, value)
	end
end

function InstanceMethods:GetFullName()
	local parts = {}
	local node = self

	while node ~= nil do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end

	return table.concat(parts, ".")
end

function InstanceMethods:FindFirstChild(name: string)
	return self._childrenByName[name]
end

function InstanceMethods:FindFirstChildOfClass(className: string)
	for _, child in ipairs(self._children) do
		if child.ClassName == className then
			return child
		end
	end

	return nil
end

function InstanceMethods:FindFirstChildWhichIsA(className: string, recursive: boolean?)
	for _, child in ipairs(self._children) do
		if child:IsA(className) then
			return child
		end

		if recursive then
			local descendant = child:FindFirstChildWhichIsA(className, true)

			if descendant ~= nil then
				return descendant
			end
		end
	end

	return nil
end

function InstanceMethods:WaitForChild(name: string, timeout: number?)
	local child = self:FindFirstChild(name)

	if child ~= nil then
		return child
	end

	local runtime = rawget(self, "_runtime")
	local scheduler = runtime and runtime.scheduler

	if scheduler == nil then
		error(`WaitForChild("{name}") requires a scheduler when the child is missing`, 2)
	end

	return scheduler:waitForSignal(getSignal(self, "ChildAdded"), function(candidate)
		return candidate.Name == name
	end, timeout)
end

function InstanceMethods:GetChildren()
	return cloneArray(self._children)
end

function InstanceMethods:GetDescendants()
	local descendants = {}
	local stack = cloneArray(self._children)

	while #stack > 0 do
		local child = table.remove(stack, 1)
		table.insert(descendants, child)

		for _, grandChild in ipairs(child._children) do
			table.insert(stack, grandChild)
		end
	end

	return descendants
end

function InstanceMethods:IsA(className: string)
	return ClassData.isA(self.ClassName, className)
end

function InstanceMethods:GetPropertyChangedSignal(propertyName: string)
	local propertySignals = rawget(self, "_propertySignals")
	local signal = propertySignals[propertyName]

	if signal == nil then
		signal = Signal.new(`{self.Name}.{propertyName}Changed`, rawget(self, "_signalRegistry"))
		propertySignals[propertyName] = signal
	end

	return signal
end

function InstanceMethods:SetAttribute(attributeName: string, value)
	local attributes = rawget(self, "_attributes")
	local oldValue = attributes[attributeName]

	if oldValue == value then
		return
	end

	attributes[attributeName] = value

	local signal = rawget(self, "_attributeSignals")[attributeName]

	if signal ~= nil then
		signal:Fire(value)
	end

	getSignal(self, "AttributeChanged"):Fire(attributeName)
end

function InstanceMethods:GetAttribute(attributeName: string)
	return rawget(self, "_attributes")[attributeName]
end

function InstanceMethods:GetAttributeChangedSignal(attributeName: string)
	local attributeSignals = rawget(self, "_attributeSignals")
	local signal = attributeSignals[attributeName]

	if signal == nil then
		signal = Signal.new(`{self.Name}.{attributeName}AttributeChanged`, rawget(self, "_signalRegistry"))
		attributeSignals[attributeName] = signal
	end

	return signal
end

function InstanceMethods:Destroy()
	if rawget(self, "_destroyed") then
		return
	end

	getSignal(self, "Destroying"):Fire()

	local children = cloneArray(self._children)

	for _, child in ipairs(children) do
		child:Destroy()
	end

	local runtime = rawget(self, "_runtime")

	if runtime ~= nil and runtime._onInstanceDestroying ~= nil then
		runtime:_onInstanceDestroying(self)
	end

	self.Parent = nil
	rawset(self, "_destroyed", true)

	if runtime ~= nil and runtime._onInstanceDestroyed ~= nil then
		runtime:_onInstanceDestroyed(self)
	end

	for _, signal in pairs(rawget(self, "_signals")) do
		signal:DisconnectAll()
	end

	for _, signal in pairs(rawget(self, "_propertySignals")) do
		signal:DisconnectAll()
	end

	for _, signal in pairs(rawget(self, "_attributeSignals")) do
		signal:DisconnectAll()
	end
end

function InstanceMethods:ClearAllChildren()
	local children = cloneArray(self._children)

	for _, child in ipairs(children) do
		child:Destroy()
	end
end

function InstanceMetatable.__index(self, key)
	local rawValue = rawget(self, key)

	if rawValue ~= nil then
		return rawValue
	end

	if key == "Name" then
		return rawget(self, "_name")
	end

	if key == "Parent" then
		return rawget(self, "_parent")
	end

	local method = InstanceMethods[key]

	if method ~= nil then
		return method
	end

	local signals = rawget(self, "_signals")
	local signal = signals[key]

	if signal ~= nil then
		return signal
	end

	local properties = rawget(self, "_properties")
	local propertyPresence = rawget(self, "_propertyPresence")

	if propertyPresence[key] then
		return properties[key]
	end

	if type(key) == "string" then
		local child = rawget(self, "_childrenByName")[key]

		if child ~= nil then
			return child
		end

		local childResolver = rawget(self, "_childResolver")

		if childResolver ~= nil then
			return childResolver(self, key)
		end
	end

	return nil
end

function InstanceMetatable.__newindex(self, key, value)
	if key:sub(1, 1) == "_" then
		rawset(self, key, value)
		return
	end

	if key == "Parent" then
		setParent(self, value)
		return
	end

	if key == "Name" then
		setName(self, value)
		return
	end

	setProperty(self, key, value)
end

function InstanceMetatable.__tostring(self)
	return `{self.ClassName}<{self:GetFullName()}>`
end

local function createInstance(className: string, parent, config)
	config = config or {}
	assertSupportedClassName(className, config.allowedClassNames)

	local defaults = ClassData.getDefaults(className)
	local self = {
		_name = className,
		_parent = nil,
		_runtime = config.runtime,
		_destroyed = false,
		_children = {},
		_childrenByName = {},
		_properties = {},
		_propertyPresence = {},
		_attributes = {},
		_signals = {},
		_propertySignals = {},
		_attributeSignals = {},
		_signalRegistry = config.signalRegistry,
		ClassName = className,
		_isFakeRobloxInstance = true,
	}

	setmetatable(self, InstanceMetatable)

	getSignal(self, "Changed")
	getSignal(self, "ChildAdded")
	getSignal(self, "ChildRemoved")
	getSignal(self, "Destroying")
	getSignal(self, "AncestryChanged")
	getSignal(self, "AttributeChanged")

	for key, value in pairs(defaults) do
		self._properties[key] = value
		self._propertyPresence[key] = true
	end

	if self:IsA("BasePart") then
		if not self._propertyPresence.Position then
			self._properties.Position = Vector3.zero
			self._propertyPresence.Position = true
		end

		if not self._propertyPresence.CFrame then
			self._properties.CFrame = CFrame.new(self._properties.Position)
			self._propertyPresence.CFrame = true
		end
	end

	if parent ~= nil then
		self.Parent = parent
	end

	return self
end

function Instance.new(className: string, parent, config)
	return createInstance(className, parent, config)
end

function Instance.createFactory(config)
	config = config or {}

	return {
		new = function(className: string, parent)
			return createInstance(className, parent, config)
		end,
	}
end

return Instance
