local Vector3 = require("./Vector3")

local CFrame = {}
CFrame.__index = CFrame

local function identityRotation()
	return {
		1,
		0,
		0,
		0,
		1,
		0,
		0,
		0,
		1,
	}
end

function CFrame.new(x: any?, y: number?, z: number?)
	local position

	if type(x) == "table" and x.X ~= nil and x.Y ~= nil and x.Z ~= nil then
		position = x
	else
		position = Vector3.new(x or 0, y or 0, z or 0)
	end

	return setmetatable({
		Position = position,
		X = position.X,
		Y = position.Y,
		Z = position.Z,
		_rotation = identityRotation(),
	}, CFrame)
end

CFrame.identity = CFrame.new(0, 0, 0)

function CFrame.lookAt(position, target)
	local cf = CFrame.new(position)
	cf.LookVector = target - position
	return cf
end

function CFrame.Angles(x: number, y: number, z: number)
	local cf = CFrame.new(0, 0, 0)
	cf._angles = Vector3.new(x, y, z)
	return cf
end

function CFrame.fromEulerAnglesXYZ(x: number, y: number, z: number)
	return CFrame.Angles(x, y, z)
end

function CFrame.fromOrientation(x: number, y: number, z: number)
	return CFrame.Angles(x, y, z)
end

function CFrame:ToOrientation()
	local angles = self._angles or Vector3.zero
	return angles.X, angles.Y, angles.Z
end

function CFrame:ToEulerAnglesXYZ()
	return self:ToOrientation()
end

function CFrame:Lerp(other, alpha: number)
	return CFrame.new(self.Position:Lerp(other.Position, alpha))
end

function CFrame:Inverse()
	return CFrame.new(-self.Position)
end

function CFrame.__mul(a, b)
	if type(b) == "table" and b.Position ~= nil then
		return CFrame.new(a.Position + b.Position)
	end

	if type(b) == "table" and b.X ~= nil and b.Y ~= nil and b.Z ~= nil then
		return a.Position + b
	end

	error("Unsupported CFrame multiplication")
end

function CFrame.__add(a, b)
	return CFrame.new(a.Position + b)
end

function CFrame.__sub(a, b)
	return CFrame.new(a.Position - b)
end

function CFrame.__eq(a, b)
	return a.Position == b.Position
end

function CFrame.__tostring(self)
	return tostring(self.Position)
end

return CFrame
