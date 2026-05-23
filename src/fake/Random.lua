local FakeRandom = {}
local Methods = {}

local states = setmetatable({}, { __mode = "k" })

local UINT32 = 4294967296
local MAX_UINT32 = 4294967295
local TWO53 = 9007199254740992
local TWO26 = 67108864

assert(bit32, "FakeRandom requires bit32, available in Roblox/Luau")

local ObjectMetatable = {
	__index = Methods,

	__newindex = function()
		error("Random cannot be modified", 2)
	end,

	__metatable = "The metatable is locked",

	__tostring = function()
		return "Random"
	end,
}

local function typeName(value)
	if typeof ~= nil then
		return typeof(value)
	end

	return type(value)
end

local function isFinite(number)
	return number == number and number ~= math.huge and number ~= -math.huge
end

local function expectNumber(value, name, level)
	if type(value) ~= "number" then
		error(("%s must be a number, got %s"):format(name, typeName(value)), level or 3)
	end

	if not isFinite(value) then
		error(("%s must be a finite number"):format(name), level or 3)
	end
end

local function expectInteger(value, name, level)
	expectNumber(value, name, level or 3)

	if value % 1 ~= 0 then
		error(("%s must be an integer"):format(name), level or 3)
	end
end

local function expectRandom(self, methodName)
	if states[self] == nil then
		error(("Expected ':' not '.' calling member function Random:%s"):format(methodName), 3)
	end
end

local function normalizeSeed(seed)
	if seed == nil then
		seed = os.time() * 1000000 + math.floor(os.clock() * 1000000)
	end

	expectNumber(seed, "seed", 3)

	local state = math.floor(math.abs(seed) * 1000000) % UINT32

	state = bit32.bxor(state, bit32.rshift(state, 16))
	state = (state * 1664525 + 1013904223) % UINT32

	if seed < 0 then
		state = bit32.bxor(state, MAX_UINT32)
	end

	if state == 0 then
		state = 0x6D2B79F5
	end

	return state
end

local function makeRandom(state)
	local self = setmetatable({}, ObjectMetatable)
	states[self] = state
	return self
end

local function nextUInt32(self)
	local x = states[self]

	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	x = bit32.band(x, MAX_UINT32)

	states[self] = x

	return x
end

local function nextFraction(self)
	local hi = math.floor(nextUInt32(self) / 32)
	local lo = math.floor(nextUInt32(self) / 64)

	return (hi * TWO26 + lo) / TWO53
end

function FakeRandom.new(seed)
	return makeRandom(normalizeSeed(seed))
end

function Methods:Clone()
	expectRandom(self, "Clone")

	return makeRandom(states[self])
end

function Methods:NextNumber(min, max)
	expectRandom(self, "NextNumber")

	if min == nil then
		min = 0
	end

	if max == nil then
		max = 1
	end

	expectNumber(min, "min", 2)
	expectNumber(max, "max", 2)

	if min > max then
		error("min must be less than or equal to max", 2)
	end

	if min == max then
		return min
	end

	return min + nextFraction(self) * (max - min)
end

function Methods:NextInteger(min, max)
	expectRandom(self, "NextInteger")

	if min == nil then
		error("missing argument #1: min", 2)
	end

	if max == nil then
		error("missing argument #2: max", 2)
	end

	expectInteger(min, "min", 2)
	expectInteger(max, "max", 2)

	if min > max then
		error("min must be less than or equal to max", 2)
	end

	local range = max - min + 1

	if range <= 1 then
		return min
	end

	if range > UINT32 then
		return min + math.floor(nextFraction(self) * range)
	end

	local limit = UINT32 - (UINT32 % range)
	local value

	repeat
		value = nextUInt32(self)
	until value < limit

	return min + (value % range)
end

function Methods:NextUnitVector()
	expectRandom(self, "NextUnitVector")

	if Vector3 == nil or Vector3.new == nil then
		error("Vector3 is required for Random:NextUnitVector()", 2)
	end

	local z = self:NextNumber(-1, 1)
	local theta = self:NextNumber(0, math.pi * 2)
	local radius = math.sqrt(1 - z * z)

	return Vector3.new(radius * math.cos(theta), radius * math.sin(theta), z)
end

function Methods:Shuffle(tb)
	expectRandom(self, "Shuffle")

	if type(tb) ~= "table" then
		error(("tb must be a table, got %s"):format(typeName(tb)), 2)
	end

	local n = 0

	for key in pairs(tb) do
		if type(key) == "number" and key >= 1 and key % 1 == 0 and key > n then
			n = key
		end
	end

	for i = 1, n do
		if rawget(tb, i) == nil then
			error("tb contains nil holes in its array part", 2)
		end
	end

	for i = n, 2, -1 do
		local j = self:NextInteger(1, i)
		tb[i], tb[j] = tb[j], tb[i]
	end
end

if table.freeze then
	table.freeze(Methods)
	table.freeze(FakeRandom)
end

return FakeRandom
