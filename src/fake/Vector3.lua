local Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x: number?, y: number?, z: number?)
	return setmetatable({
		X = x or 0,
		Y = y or 0,
		Z = z or 0,
	}, Vector3)
end

Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

function Vector3:Dot(other)
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

function Vector3:Cross(other)
	return Vector3.new(
		self.Y * other.Z - self.Z * other.Y,
		self.Z * other.X - self.X * other.Z,
		self.X * other.Y - self.Y * other.X
	)
end

function Vector3:Lerp(other, alpha: number)
	return Vector3.new(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end

function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function Vector3.__mul(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end

	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

function Vector3.__div(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end

	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end

function Vector3.__unm(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end

function Vector3.__eq(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

function Vector3.__tostring(self)
	return `{self.X}, {self.Y}, {self.Z}`
end

return Vector3
