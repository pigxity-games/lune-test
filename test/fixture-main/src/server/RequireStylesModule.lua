local byRelativeString = require("../shared/StatefulModule")
local byAbsoluteString = require("test/fixture-main/src/shared/StatefulModule")
local byAbsoluteInstance = require(ReplicatedStorage.StatefulModule)
local byRelativeInstance = require(script.Parent.Parent.ReplicatedStorage.StatefulModule)
local byGameString = require("@game/ReplicatedStorage/StatefulModule")

return {
	byRelativeString = byRelativeString,
	byAbsoluteString = byAbsoluteString,
	byAbsoluteInstance = byAbsoluteInstance,
	byRelativeInstance = byRelativeInstance,
	byGameString = byGameString,
}
