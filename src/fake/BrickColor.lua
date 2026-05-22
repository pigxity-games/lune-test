local Color3 = require("./Color3")

local COLORS = {
	["White"] = { Number = 1, Color = Color3.fromRGB(242, 243, 243) },
	["Grey"] = { Number = 2, Color = Color3.fromRGB(161, 165, 162) },
	["Light yellow"] = { Number = 3, Color = Color3.fromRGB(249, 233, 153) },
	["Bright red"] = { Number = 21, Color = Color3.fromRGB(196, 40, 28) },
	["Bright blue"] = { Number = 23, Color = Color3.fromRGB(13, 105, 172) },
	["Bright yellow"] = { Number = 24, Color = Color3.fromRGB(245, 205, 48) },
	["Black"] = { Number = 26, Color = Color3.fromRGB(27, 42, 53) },
	["Dark green"] = { Number = 28, Color = Color3.fromRGB(40, 127, 71) },
	["Medium stone grey"] = { Number = 194, Color = Color3.fromRGB(163, 162, 165) },
	["Really red"] = { Number = 1004, Color = Color3.fromRGB(255, 0, 0) },
	["Really blue"] = { Number = 1003, Color = Color3.fromRGB(0, 0, 255) },
	["Lime green"] = { Number = 1020, Color = Color3.fromRGB(0, 255, 0) },
}

local NUMBER_TO_NAME = {}

for name, data in pairs(COLORS) do
	NUMBER_TO_NAME[data.Number] = name
end

local BrickColor = {}
BrickColor.__index = BrickColor

local function create(name: string)
	local data = COLORS[name]

	if data == nil then
		name = "Medium stone grey"
		data = COLORS[name]
	end

	return setmetatable({
		Name = name,
		Number = data.Number,
		Color = data.Color,
	}, BrickColor)
end

function BrickColor.new(value: any?)
	if type(value) == "number" then
		return create(NUMBER_TO_NAME[value] or "Medium stone grey")
	end

	if type(value) == "string" then
		return create(value)
	end

	if type(value) == "table" and value.R ~= nil then
		return BrickColor.closest(value)
	end

	return create("Medium stone grey")
end

function BrickColor.White()
	return create("White")
end

function BrickColor.Gray()
	return create("Grey")
end

function BrickColor.Grey()
	return create("Grey")
end

function BrickColor.Black()
	return create("Black")
end

function BrickColor.Red()
	return create("Bright red")
end

function BrickColor.Blue()
	return create("Bright blue")
end

function BrickColor.Yellow()
	return create("Bright yellow")
end

function BrickColor.Green()
	return create("Dark green")
end

function BrickColor.random()
	local names = {}

	for name in pairs(COLORS) do
		table.insert(names, name)
	end

	return create(names[math.random(1, #names)])
end

function BrickColor.palette(index: number)
	local names = {}

	for name in pairs(COLORS) do
		table.insert(names, name)
	end

	table.sort(names)

	return create(names[((index - 1) % #names) + 1])
end

function BrickColor.closest(color)
	local bestName = nil
	local bestDistance = math.huge

	for name, data in pairs(COLORS) do
		local dr = color.R - data.Color.R
		local dg = color.G - data.Color.G
		local db = color.B - data.Color.B
		local distance = dr * dr + dg * dg + db * db

		if distance < bestDistance then
			bestDistance = distance
			bestName = name
		end
	end

	return create(bestName or "Medium stone grey")
end

function BrickColor.__eq(a, b)
	return a.Number == b.Number
end

function BrickColor.__tostring(self)
	return self.Name
end

return BrickColor
