local StatefulModule = require("@legacy/shared/StatefulModule")

assert(StatefulModule.getCount() == 0)

return StatefulModule
