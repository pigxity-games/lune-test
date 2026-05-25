local TestHelpers = require("@test/test_helpers")

local m = {}

function m.add(a: number, b: number)
	return TestHelpers.add(a, b)
end

return m
