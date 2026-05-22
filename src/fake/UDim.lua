local UDim = {}
UDim.__index = UDim

function UDim.new(scale: number?, offset: number?)
	return setmetatable({
		Scale = scale or 0,
		Offset = offset or 0,
	}, UDim)
end

function UDim.__add(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end

function UDim.__sub(a, b)
	return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset)
end

function UDim.__eq(a, b)
	return a.Scale == b.Scale and a.Offset == b.Offset
end

function UDim.__tostring(self)
	return `{self.Scale}, {self.Offset}`
end

return UDim
