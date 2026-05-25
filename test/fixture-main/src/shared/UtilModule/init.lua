local ChildModule = require("@self/ChildModule")

local m = {}

function m.add(a: number, b: number)
	return ChildModule.add(a, b)
end

return m
