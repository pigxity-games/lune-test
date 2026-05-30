local helperByRelativePath = require("./helper")
local helperBySelfPath = require("@self/helper")

return {
	relativeRequireWorks = function()
		assert(helperByRelativePath.value == 123)
	end,

	selfRequireWorks = function()
		assert(helperBySelfPath.value == 123)
	end,
}
