local m = {}

function m.replicatedStorageAndRelativeRequires()
	local SomeModule = require("./src/server/SomeModule")
	local add = SomeModule.add

	_G.SomeGlobal = "Hello World"
	SomeModule.AValue = "Test"
	assert(add(1, 1) == 2, "1+1 is not 2")
	assert(add(2, 2) == 4, "2+2 is not 4")
end

function m.playerScriptsClientRequires()
	local ClientModule1 = require("./src/client/ClientModule1")
	local multiply = ClientModule1.multiply

	assert(multiply(2, 2) == 4, "2*2 is not 4")
	assert(multiply(4, 4) == 16, "4*4 is not 16")
end

function m.starterPlayerScriptsClientRequires()
	local StarterPlayer = game:GetService("StarterPlayer")
	local ClientModule1 = require(StarterPlayer.StarterPlayerScripts.ClientModule1)
	local multiply = ClientModule1.multiply

	assert(multiply(3, 2) == 6, "3*2 is not 6")
	assert(multiply(5, 4) == 20, "5*4 is not 20")
end

function m.aliasRequires()
	local SomeModule = require("@test/fixture-main/src/server/SomeModule")
	assert(SomeModule.add(1, 1) == 2, "1+1 is not 2")
end

return m
