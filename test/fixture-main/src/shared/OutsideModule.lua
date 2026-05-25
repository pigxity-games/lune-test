local UtilModule = require("./UtilModule")

local m = {}

function m.add(a: number, b: number)
	return UtilModule.add(a, b)
end

return m
