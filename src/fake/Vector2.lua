local Vector2 = {}
Vector2.__index = Vector2

function Vector2.new(x: number?, y: number?)
	return setmetatable({
		X = x or 0,
		Y = y or 0,
	}, Vector2)
end

Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
Vector2.xAxis = Vector2.new(1, 0)
Vector2.yAxis = Vector2.new(0, 1)

function Vector2:Dot(other)
	return self.X * other.X + self.Y * other.Y
end

function Vector2:Lerp(other, alpha: number)
	return Vector2.new(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha
	)
end

function Vector2.__add(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end

function Vector2.__sub(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end

function Vector2.__mul(a, b)
	if type(a) == "number" then
		return Vector2.new(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end

	return Vector2.new(a.X * b.X, a.Y * b.Y)
end

function Vector2.__div(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X / b, a.Y / b)
	end

	return Vector2.new(a.X / b.X, a.Y / b.Y)
end

function Vector2.__unm(a)
	return Vector2.new(-a.X, -a.Y)
end

function Vector2.__eq(a, b)
	return a.X == b.X and a.Y == b.Y
end

function Vector2.__tostring(self)
	return `{self.X}, {self.Y}`
end

return Vector2