local Instance = {}

local InstanceMethods = {}

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
	return self._children[name]
end

function InstanceMethods:WaitForChild(name: string)
	local child = self._children[name]

	if child == nil then
		child = Instance.new("ModuleScript")
		child.Name = name
		child.Parent = self
	end

	return child
end

function InstanceMethods:GetChildren()
	local children = {}

	for _, child in pairs(self._children) do
		table.insert(children, child)
	end

	return children
end

function InstanceMethods:IsA(className: string)
	return self.ClassName == className
end

function InstanceMethods:Destroy()
	if self.Parent ~= nil then
		self.Parent._children[self.Name] = nil
	end

	self.Parent = nil
	self._children = {}
end

local InstanceMetatable = {}

function InstanceMetatable.__index(self, key)
	local method = InstanceMethods[key]

	if method ~= nil then
		return method
	end

	if type(key) == "string" then
		local child = self._children[key]

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
	if key == "Parent" then
		local oldParent = rawget(self, "Parent")
		local name = rawget(self, "Name")

		if oldParent ~= nil and name ~= nil then
			oldParent._children[name] = nil
		end

		rawset(self, "Parent", value)

		if value ~= nil then
			value._children[name] = self
		end

		return
	end

	if key == "Name" then
		local parent = rawget(self, "Parent")
		local oldName = rawget(self, "Name")

		if parent ~= nil and oldName ~= nil then
			parent._children[oldName] = nil
		end

		rawset(self, "Name", value)

		if parent ~= nil then
			parent._children[value] = self
		end

		return
	end

	rawset(self, key, value)
end

function Instance.new(className: string, parent)
	local self = {
		Name = className,
		ClassName = className,
		Parent = nil,

		_children = {},
		_isFakeRobloxInstance = true,
	}

	setmetatable(self, InstanceMetatable)

	if parent ~= nil then
		self.Parent = parent
	end

	return self
end

return Instance
