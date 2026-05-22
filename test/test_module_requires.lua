local SomeModule = require("@src/server/SomeModule")
local add = SomeModule.add

local m = {}

function m.addFunctionAddsTwoNumbers()
	_G.SomeGlobal = "Hello World"
	SomeModule.AValue = "Test"
	assert(add(1, 1) == 2, "1+1 is not 2")
	assert(add(2, 2) == 4, "2+2 is not 4")
end

return m
