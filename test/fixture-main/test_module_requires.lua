local m = {}

local function assertContains(haystack: string, needle: string)
	assert(haystack:find(needle, 1, true) ~= nil, string.format('expected "%s" to contain "%s"', haystack, needle))
end

local function assertRequireError(callback, expectedMessage: string)
	local ok, err = pcall(callback)
	assert(not ok, "expected require to error")
	assertContains(tostring(err), expectedMessage)
end

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

function m.invalidRequiresProduceErrors()
	assertRequireError(function()
		require(ReplicatedStorage.InvalidPath)
	end, "Cannot require value of type nil")

	assertRequireError(function()
		require(123)
	end, "Cannot require value of type number")

	assertRequireError(function()
		require("/invalidPath")
	end, 'Unable to resolve module path "invalidPath"')

	assertRequireError(function()
		require("12345")
	end, 'Unable to resolve module path "12345"')

	assertRequireError(function()
		require("./invalidPath")
	end, "missing module source for")

	assertRequireError(function()
		require("./")
	end, "missing module source for")

	assertRequireError(function()
		require("/")
	end, 'Unable to resolve module path ""')

	assertRequireError(function()
		require("../")
	end, "missing module source for")

	assertRequireError(function()
		require("./src")
	end, "missing module source for")

	assertRequireError(function()
		require("@invalidAlias")
	end, 'Unable to resolve module path "@invalidAlias"')

	assertRequireError(function()
		require("@alias")
	end, 'Unable to resolve module path "@alias"')

	assertRequireError(function()
		require("@alias/invalidPath")
	end, 'Unable to resolve module path "@alias/invalidPath"')
end

return m
