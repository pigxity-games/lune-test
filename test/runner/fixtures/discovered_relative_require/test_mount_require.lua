local ReplicatedStorage = game:GetService("ReplicatedStorage")
local helper = require(ReplicatedStorage.TestHelpers.helper)

return {
	mountedRequireWorks = function()
		assert(helper.value == 456)
	end,
}
