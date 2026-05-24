local ClassData = {}

local parentByClass = {
	Instance = nil,
	DataModel = "Instance",
	Folder = "Instance",
	Model = "Instance",
	Tool = "Model",
	Backpack = "Folder",
	Workspace = "Model",
	BasePart = "Instance",
	Part = "BasePart",
	SpawnLocation = "BasePart",
	NumberValue = "Instance",
	RemoteEvent = "Instance",
	RemoteFunction = "Instance",
	Player = "Instance",
	Players = "Instance",
	RunService = "Instance",
	CollectionService = "Instance",
	MemoryStoreService = "Instance",
	TeleportService = "Instance",
	ReplicatedStorage = "Instance",
	ServerScriptService = "Instance",
	StarterPlayer = "Instance",
	StarterPlayerScripts = "Instance",
	PlayerScripts = "Instance",
	ModuleScript = "Instance",
	LocalScript = "Instance",
	TeleportOptions = "Instance",
}

local defaultPropsByClass = {
	Instance = {},
	DataModel = {},
	Folder = {},
	Model = {},
	Tool = {
		RequiresHandle = false,
		Enabled = true,
	},
	Backpack = {},
	Workspace = {},
	BasePart = {
		Anchored = false,
		CanCollide = true,
		Transparency = 0,
	},
	Part = {},
	SpawnLocation = {
		Neutral = true,
	},
	NumberValue = {
		Value = 0,
	},
	RemoteEvent = {},
	RemoteFunction = {},
	Player = {
		UserId = 0,
		AccountAge = 0,
		MembershipType = "None",
	},
	Players = {},
	RunService = {},
	CollectionService = {},
	MemoryStoreService = {},
	TeleportService = {},
	ReplicatedStorage = {},
	ServerScriptService = {},
	StarterPlayer = {},
	StarterPlayerScripts = {},
	PlayerScripts = {},
	ModuleScript = {},
	LocalScript = {},
	TeleportOptions = {
		ReservedServerAccessCode = "",
		TeleportData = nil,
	},
}

function ClassData.getParent(className: string): string?
	return parentByClass[className]
end

function ClassData.isSupported(className: string): boolean
	return parentByClass[className] ~= nil or className == "Instance"
end

function ClassData.isA(className: string, targetClassName: string): boolean
	local cursor = className

	while cursor ~= nil do
		if cursor == targetClassName then
			return true
		end

		cursor = parentByClass[cursor]
	end

	return false
end

function ClassData.getDefaults(className: string)
	local merged = {}
	local lineage = {}
	local cursor = className

	while cursor ~= nil do
		table.insert(lineage, 1, cursor)
		cursor = parentByClass[cursor]
	end

	for _, ancestor in ipairs(lineage) do
		for key, value in pairs(defaultPropsByClass[ancestor] or {}) do
			merged[key] = value
		end
	end

	return merged
end

function ClassData.list()
	local names = {}

	for className in pairs(parentByClass) do
		table.insert(names, className)
	end

	table.sort(names)

	return names
end

return ClassData
