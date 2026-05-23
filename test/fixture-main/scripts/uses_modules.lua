local SomeModule = require(ServerScriptService.SomeModule)
local UtilModule = require(ReplicatedStorage.UtilModule)

assert(SomeModule.add(6, 5) == 11)
assert(UtilModule.add(3, 4) == 7)
