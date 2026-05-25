local function waitForPath(path)
	local current = path[1]

	for index = 2, #path do
		current = current:WaitForChild(path[index])
	end

	return current
end

local replicatedStorage = game:GetService("ReplicatedStorage")
local lifecycle = waitForPath({ replicatedStorage, "Generated", "_Internal", "Lifecycle" })

assert(lifecycle.Name == "Lifecycle")

return lifecycle
