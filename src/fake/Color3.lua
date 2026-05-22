-- fake/Color3.luau

local Color3 = {}
Color3.__index = Color3

local function clamp01(value: number): number
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end

	return value
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

function Color3.new(r: number, g: number, b: number)
	local self = {
		R = clamp01(r),
		G = clamp01(g),
		B = clamp01(b),
	}

	return setmetatable(self, Color3)
end

function Color3.fromRGB(r: number, g: number, b: number)
	return Color3.new(r / 255, g / 255, b / 255)
end

function Color3.fromHSV(h: number, s: number, v: number)
	h = h % 1
	s = clamp01(s)
	v = clamp01(v)

	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)

	i = i % 6

	if i == 0 then
		return Color3.new(v, t, p)
	elseif i == 1 then
		return Color3.new(q, v, p)
	elseif i == 2 then
		return Color3.new(p, v, t)
	elseif i == 3 then
		return Color3.new(p, q, v)
	elseif i == 4 then
		return Color3.new(t, p, v)
	else
		return Color3.new(v, p, q)
	end
end

function Color3:ToHSV()
	local r = self.R
	local g = self.G
	local b = self.B

	local maxValue = math.max(r, g, b)
	local minValue = math.min(r, g, b)
	local delta = maxValue - minValue

	local h = 0

	if delta ~= 0 then
		if maxValue == r then
			h = ((g - b) / delta) % 6
		elseif maxValue == g then
			h = ((b - r) / delta) + 2
		else
			h = ((r - g) / delta) + 4
		end

		h /= 6
	end

	local s = if maxValue == 0 then 0 else delta / maxValue
	local v = maxValue

	return h, s, v
end

function Color3:Lerp(other, alpha: number)
	return Color3.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

function Color3:ToHex(): string
	local r = round(self.R * 255)
	local g = round(self.G * 255)
	local b = round(self.B * 255)

	return string.format("%02X%02X%02X", r, g, b)
end

function Color3.__eq(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end

function Color3.__tostring(self)
	return string.format("%s, %s, %s", self.R, self.G, self.B)
end

return Color3