local replicatedStorage = game:GetService("ReplicatedStorage")

return {
	waitsForMissingGenerated = function()
		return replicatedStorage:WaitForChild("Generated")
	end,
}
