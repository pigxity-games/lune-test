local SomeModule = require("@src/server/SomeModule")
local add = SomeModule.add

local m = {}

function m.sandboxedGlobalState1()
    assert(SomeModule.AValue == "1")
    assert(_G.SomeGlobal == nil)
    SomeModule.AValue = "123"
    _G.SomeGlobal = "123"
end

function m.sandboxedGlobalState2()
    assert(SomeModule.AValue == nil)
    assert(_G.SomeGlobal == "1")
    SomeModule.AValue = "123"
    _G.SomeGlobal = "123"
end

return m