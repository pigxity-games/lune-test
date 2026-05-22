local UDim = require("./UDim")

local UDim2 = {}
UDim2.__index = UDim2

function UDim2.new(
	xScale: number?,
	xOffset: number?,
	yScale: number?,
	yOffset: number?
)
	return setmetatable({
		X = UDim.new(xScale or 0, xOffset or 0),
		Y = UDim.new(yScale or 0, yOffset or 0),
	}, UDim2)
end

function UDim2.fromScale(xScale: number, yScale: number)
	return UDim2.new(xScale, 0, yScale, 0)
end

function UDim2.fromOffset(xOffset: number, yOffset: number)
	return UDim2.new(0, xOffset, 0, yOffset)
end

function UDim2:Lerp(other, alpha: number)
	return UDim2.new(
		self.X.Scale + (other.X.Scale - self.X.Scale) * alpha,
		self.X.Offset + (other.X.Offset - self.X.Offset) * alpha,
		self.Y.Scale + (other.Y.Scale - self.Y.Scale) * alpha,
		self.Y.Offset + (other.Y.Offset - self.Y.Offset) * alpha
	)
end

function UDim2.__add(a, b)
	return UDim2.new(
		a.X.Scale + b.X.Scale,
		a.X.Offset + b.X.Offset,
		a.Y.Scale + b.Y.Scale,
		a.Y.Offset + b.Y.Offset
	)
end

function UDim2.__sub(a, b)
	return UDim2.new(
		a.X.Scale - b.X.Scale,
		a.X.Offset - b.X.Offset,
		a.Y.Scale - b.Y.Scale,
		a.Y.Offset - b.Y.Offset
	)
end

function UDim2.__eq(a, b)
	return a.X == b.X and a.Y == b.Y
end

function UDim2.__tostring(self)
	return `{self.X.Scale}, {self.X.Offset}, {self.Y.Scale}, {self.Y.Offset}`
end

return UDim2