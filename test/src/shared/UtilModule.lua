local UtilModule2 = require(script.Parent.UtilModule2)

local m = {}

function m.add(a: number, b: number)
    return UtilModule2.add(a, b)
end

return m