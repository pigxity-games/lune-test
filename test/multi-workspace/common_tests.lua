local helpers = require("./test_helpers")

local m = {}

function m.otherWorkspaceModulesNil(...)
	for _, path in ipairs({ ... }) do
		assert(helpers.getPath(game, table.unpack(path)) == nil)
	end
end

function m.commonSharedModuleDividesTwoNumbers(a: number, b: number, expected: number)
	local CommonModule = require(game:GetService("ReplicatedStorage").Common.CommonModule)

	assert(CommonModule.divide(a, b) == expected, `{a}/{b} is not {expected}`)
end

return m
