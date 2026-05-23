local StatefulModule = require(ReplicatedStorage.StatefulModule)

assert(_G.ScriptModeValue == nil)
assert(StatefulModule.getCount() == 0)
