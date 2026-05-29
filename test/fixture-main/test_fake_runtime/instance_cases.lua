local TestHelpers = require("@test/test_helpers")
local assertEqual = TestHelpers.assertEqual
local assertSequenceEqual = TestHelpers.assertSequenceEqual

local m = {}

function m.instanceHierarchyAttributesAndSignals()
	local env = createEnvironment({
		activePlayers = {},
	})
	local root = env.Instance.new("Model")
	local folder = env.Instance.new("Folder")
	local tool = env.Instance.new("Tool")
	local part = env.Instance.new("Part")
	local value = env.Instance.new("NumberValue")
	local childAddedNames = {}
	local childRemovedNames = {}
	local attributeChanges = {}
	local propertyChanges = {}
	local changedValues = {}

	root.Name = "Root"
	folder.Name = "Inventory"
	tool.Name = "Hammer"
	part.Name = "Handle"
	value.Name = "Coins"

	root.ChildAdded:Connect(function(child)
		table.insert(childAddedNames, child.Name)
	end)

	root.ChildRemoved:Connect(function(child)
		table.insert(childRemovedNames, child.Name)
	end)

	part:GetAttributeChangedSignal("Health"):Connect(function()
		table.insert(attributeChanges, part:GetAttribute("Health"))
	end)

	part:GetPropertyChangedSignal("Position"):Connect(function()
		table.insert(propertyChanges, tostring(part.Position))
	end)

	value.Changed:Connect(function(newValue)
		table.insert(changedValues, newValue)
	end)

	folder.Parent = root
	tool.Parent = root
	part.Parent = tool
	value.Parent = root

	assertSequenceEqual(childAddedNames, { "Inventory", "Hammer", "Coins" }, "child added order")
	assertEqual(root:FindFirstChild("Inventory"), folder)

	assertEqual(root:FindFirstChildOfClass("Tool"), tool)
	assertEqual(tool:FindFirstChildWhichIsA("BasePart"), part)
	assertEqual(tool:FindFirstChildOfClass("Part"), part)

	assertEqual(tool:FindFirstChildWhichIsA("BasePart"), part)
	assertEqual(tool:FindFirstChildOfClass("Part"), part)
	assertEqual(tool:FindFirstChildOfClass("BasePart"), nil)

	assertEqual(#root:GetChildren(), 3)
	assertEqual(#root:GetDescendants(), 4)
	assert(part:IsA("BasePart"))

	assertEqual(root:FindFirstChildWhichIsA("BasePart"), nil)
	assertEqual(root:FindFirstChildWhichIsA("BasePart", true), part)

	part.Position = Vector3.new(1, 2, 3)
	assertEqual(part.CFrame.Position.X, 1)
	assertEqual(part.CFrame.Position.Y, 2)
	assertEqual(part.CFrame.Position.Z, 3)
	part.CFrame = CFrame.new(4, 5, 6)
	assertEqual(part.Position.X, 4)
	assertEqual(part.Position.Y, 5)
	assertEqual(part.Position.Z, 6)
	assertSequenceEqual(propertyChanges, { "1, 2, 3", "4, 5, 6" }, "position changes")

	part:SetAttribute("Health", 100)
	part:SetAttribute("Health", 200)
	assertSequenceEqual(attributeChanges, { 100, 200 }, "attribute changes")
	assertEqual(part:GetAttribute("Health"), 200)

	local healthRemoved = false

	part:GetAttributeChangedSignal("HealthRemovedTest"):Connect(function()
		healthRemoved = part:GetAttribute("HealthRemovedTest") == nil
	end)

	part:SetAttribute("HealthRemovedTest", 10)
	part:SetAttribute("HealthRemovedTest", nil)

	assertEqual(part:GetAttribute("HealthRemovedTest"), nil)
	assert(healthRemoved)

	value.Value = 15
	assertSequenceEqual(changedValues, { 15 }, "number value changes")

	local waited = nil
	env.task.spawn(function()
		waited = root:WaitForChild("AsyncFolder", 1)
	end)
	env.task.defer(function()
		local asyncFolder = env.Instance.new("Folder")
		asyncFolder.Name = "AsyncFolder"
		asyncFolder.Parent = root
	end)
	env.scheduler:flush()
	assertEqual(waited.Name, "AsyncFolder")

	local ok, err = pcall(function()
		root.Parent = part
	end)
	assert(not ok)
	assert(err:find("descendants") ~= nil)

	folder:Destroy()
	assertSequenceEqual(childRemovedNames, { "Inventory" }, "child removed order")
	assert(root:FindFirstChild("Inventory") == nil)
end

function m.instanceEventSemanticsAndChildClearing()
	local env = createEnvironment({
		activePlayers = {},
	})
	local root = env.Instance.new("Folder")
	local child = env.Instance.new("Folder")
	local grandChild = env.Instance.new("Part")
	local ancestryParents = {}
	local destroyingCount = 0
	local changedProperties = {}
	local nameChanges = {}

	root.Name = "Root"
	child.Name = "Child"
	grandChild.Name = "GrandChild"

	child.AncestryChanged:Connect(function(_, parent)
		table.insert(ancestryParents, if parent ~= nil then parent.Name else "nil")
	end)
	child.Destroying:Connect(function()
		destroyingCount += 1
	end)
	grandChild.Destroying:Connect(function()
		destroyingCount += 1
	end)
	grandChild.Changed:Connect(function(propertyName)
		table.insert(changedProperties, propertyName)
	end)
	grandChild:GetPropertyChangedSignal("Name"):Connect(function()
		table.insert(nameChanges, grandChild.Name)
	end)

	child.Parent = root
	child.Parent = nil
	child.Parent = root
	grandChild.Parent = child

	grandChild.Name = "Renamed"
	grandChild.Transparency = 0.5
	grandChild.Transparency = 0.5

	assertSequenceEqual(ancestryParents, { "Root", "nil", "Root" }, "ancestry change order")
	assertSequenceEqual(nameChanges, { "Renamed" }, "name change signal")
	assertSequenceEqual(changedProperties, { "Name", "Transparency" }, "changed properties")

	root:ClearAllChildren()
	assertEqual(destroyingCount, 2)
	assertEqual(#root:GetChildren(), 0)
	assertEqual(#child:GetChildren(), 0)
end

function m.waitForChildImmediateTimeoutAndNoSchedulerErrors()
	local env = createEnvironment({
		activePlayers = {},
	})
	local folder = env.Instance.new("Folder")
	local existing = env.Instance.new("Folder")
	local waited = "pending"

	folder.Name = "Container"
	existing.Name = "Existing"
	existing.Parent = folder

	assertEqual(folder:WaitForChild("Existing", 5), existing)

	env.task.spawn(function()
		waited = folder:WaitForChild("Missing", 2)
	end)
	env.scheduler:flush()
	env.scheduler:advance(2)
	assert(waited == nil)

	local standalone = Instance.new("Folder")
	local waited2 = standalone:WaitForChild("Missing")
	assertEqual(waited2, nil)
end

function m.waitForChildResolvesWhenChildIsRenamedAfterParenting()
	local env = createEnvironment({
		activePlayers = {},
	})
	local folder = env.Instance.new("Folder")
	local waited

	env.task.spawn(function()
		waited = folder:WaitForChild("Child", 1)
	end)

	env.task.defer(function()
		local child = env.Instance.new("Folder", folder)
		child.Name = "Child"
	end)

	env.scheduler:runAll()
	assertEqual(waited, folder.Child)
end

function m.waitForChildToplevel()
	local items = Instance.new("Folder", ReplicatedStorage)
	items.Name = "Items"

	local waited = ReplicatedStorage:WaitForChild("Items")
	assertEqual(waited, items)

	local waited2 = items:WaitForChild("Parts")
	assertEqual(waited2, nil)

	local parts = Instance.new("Folder", items)
	parts.Name = "Parts"

	assertEqual(waited2, nil)

	local waited3 = items:WaitForChild("Parts")
	assertEqual(waited3, parts)
end

function m.waitForChildToplevelMissingServiceChildReturnsNil()
	local waited = ReplicatedStorage:WaitForChild("Items")

	assertEqual(waited, nil)
end

return m
