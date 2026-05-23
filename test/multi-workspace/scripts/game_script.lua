local SomeGameModule = require(ServerScriptService.Game.SomeGameModule)
local SharedGameModule = require(ServerScriptService.Utils.SharedGameModule)

assert(SomeGameModule.add(8, 3) == 11)
assert(SharedGameModule.average(10, 6) == 8)

print("Hello World")
