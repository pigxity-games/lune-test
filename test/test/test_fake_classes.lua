local m = {}

local function assertEqual(actual, expected, message)
	assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

local function assertVector2Equal(actual, x, y)
	assertEqual(actual, Vector2.new(x, y))
end

local function assertVector3Equal(actual, x, y, z)
	assertEqual(actual, Vector3.new(x, y, z))
end

local function assertUDimEqual(actual, scale, offset)
	assertEqual(actual, UDim.new(scale, offset))
end

local function assertUDim2Equal(actual, xScale, xOffset, yScale, yOffset)
	assertEqual(actual, UDim2.new(xScale, xOffset, yScale, yOffset))
end

local function assertColor3Equal(actual, expected)
	assertEqual(actual, expected, string.format("expected Color3 %s, got %s", tostring(expected), tostring(actual)))
end

local function assertClose(actual, expected, epsilon, label)
	local difference = math.abs(actual - expected)
	assert(
		difference <= epsilon,
		string.format("%s expected %.6f, got %.6f (difference %.6f)", label or "value", expected, actual, difference)
	)
end

function m.vector2DefaultsAndConstants()
	assertVector2Equal(Vector2.new(), 0, 0)
	assertEqual(Vector2.zero, Vector2.new(0, 0))
	assertEqual(Vector2.one, Vector2.new(1, 1))
	assertEqual(Vector2.xAxis, Vector2.new(1, 0))
	assertEqual(Vector2.yAxis, Vector2.new(0, 1))
end

function m.vector2ArithmeticAndHelpers()
	local a = Vector2.new(10, 20)
	local b = Vector2.new(4, 5)

	assertVector2Equal(a + b, 14, 25)
	assertVector2Equal(a - b, 6, 15)
	assertVector2Equal(a * 2, 20, 40)
	assertVector2Equal(3 * b, 12, 15)
	assertVector2Equal(a / 2, 5, 10)
	assertVector2Equal(-b, -4, -5)
	assertEqual(a:Dot(b), 140)
	assertVector2Equal(a:Lerp(b, 0.25), 8.5, 16.25)
	assertEqual(tostring(Vector2.new(7, 8)), "7, 8")
end

function m.vector3ArithmeticAndCrossProduct()
	local a = Vector3.new(3, 4, 5)
	local b = Vector3.new(1, 2, 3)

	assertVector3Equal(a + b, 4, 6, 8)
	assertVector3Equal(a - b, 2, 2, 2)
	assertVector3Equal(a * 2, 6, 8, 10)
	assertVector3Equal(2 * b, 2, 4, 6)
	assertVector3Equal(a / 2, 1.5, 2, 2.5)
	assertVector3Equal(-b, -1, -2, -3)
	assertEqual(a:Dot(b), 26)
	assertVector3Equal(Vector3.xAxis:Cross(Vector3.yAxis), 0, 0, 1)
	assertEqual(tostring(Vector3.new(7, 8, 9)), "7, 8, 9")
end

function m.vector3HelpersAndConstants()
	assertVector3Equal(Vector3.new(), 0, 0, 0)
	assertEqual(Vector3.zero, Vector3.new(0, 0, 0))
	assertEqual(Vector3.one, Vector3.new(1, 1, 1))
	assertEqual(Vector3.xAxis, Vector3.new(1, 0, 0))
	assertEqual(Vector3.yAxis, Vector3.new(0, 1, 0))
	assertEqual(Vector3.zAxis, Vector3.new(0, 0, 1))
	assertVector3Equal(Vector3.new(0, 0, 0):Lerp(Vector3.new(8, 4, 2), 0.5), 4, 2, 1)
end

function m.udimArithmetic()
	local a = UDim.new(0.5, 12)
	local b = UDim.new(0.25, -2)

	assertUDimEqual(UDim.new(), 0, 0)
	assertUDimEqual(a + b, 0.75, 10)
	assertUDimEqual(a - b, 0.25, 14)
	assertEqual(tostring(UDim.new(1, 8)), "1, 8")
end

function m.udim2ConstructorsAndLerp()
	local a = UDim2.new(0.5, 12, 1, 4)
	local b = UDim2.fromOffset(20, 10)

	assertUDim2Equal(UDim2.fromScale(1, 0.25), 1, 0, 0.25, 0)
	assertUDim2Equal(b, 0, 20, 0, 10)
	assertUDim2Equal(a + b, 0.5, 32, 1, 14)
	assertUDim2Equal(a - b, 0.5, -8, 1, -6)
	assertUDim2Equal(a:Lerp(UDim2.new(1, 20, 0, 10), 0.5), 0.75, 16, 0.5, 7)
	assertEqual(tostring(UDim2.new(1, 2, 3, 4)), "1, 2, 3, 4")
end

function m.color3RgbHexAndClamp()
	local clamped = Color3.new(-0.5, 0.5, 2)

	assertColor3Equal(clamped, Color3.new(0, 0.5, 1))
	assertColor3Equal(Color3.fromRGB(255, 128, 0), Color3.new(1, 128 / 255, 0))
	assertEqual(Color3.fromRGB(255, 128, 0):ToHex(), "FF8000")
	assertEqual(tostring(Color3.new(1, 0.5, 0)), "1, 0.5, 0")
end

function m.color3HsvRoundTripAndLerp()
	local color = Color3.fromHSV(0.25, 0.75, 0.8)
	local h, s, v = color:ToHSV()

	assertClose(h, 0.25, 1e-6, "hue")
	assertClose(s, 0.75, 1e-6, "saturation")
	assertClose(v, 0.8, 1e-6, "value")
	assertColor3Equal(Color3.new(0, 0, 0):Lerp(Color3.new(1, 0.5, 0.25), 0.5), Color3.new(0.5, 0.25, 0.125))
end

function m.cframeConstructionAndOperators()
	local position = Vector3.new(1, 2, 3)
	local base = CFrame.new(position)
	local offset = CFrame.new(4, 5, 6)

	assertEqual(base.Position, position)
	assertEqual(base, CFrame.new(1, 2, 3))
	assertEqual(CFrame.identity, CFrame.new(0, 0, 0))
	assertEqual(base * offset, CFrame.new(5, 7, 9))
	assertVector3Equal(base * Vector3.new(10, 20, 30), 11, 22, 33)
	assertEqual(base + Vector3.new(2, 3, 4), CFrame.new(3, 5, 7))
	assertEqual(base - Vector3.new(1, 1, 1), CFrame.new(0, 1, 2))
	assertEqual(base:Inverse(), CFrame.new(-1, -2, -3))
	assertEqual(base:Lerp(CFrame.new(5, 6, 7), 0.5), CFrame.new(3, 4, 5))
	assertEqual(tostring(base), "1, 2, 3")
end

function m.cframeOrientationAndLookAt()
	local rotated = CFrame.Angles(0.1, 0.2, 0.3)
	local x, y, z = rotated:ToOrientation()
	local ex, ey, ez = rotated:ToEulerAnglesXYZ()
	local fx, fy, fz = CFrame.fromEulerAnglesXYZ(0.4, 0.5, 0.6):ToOrientation()
	local ox, oy, oz = CFrame.fromOrientation(0.7, 0.8, 0.9):ToOrientation()
	local lookAt = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -10))

	assertClose(x, 0.1, 1e-6, "orientation x")
	assertClose(y, 0.2, 1e-6, "orientation y")
	assertClose(z, 0.3, 1e-6, "orientation z")
	assertClose(ex, 0.1, 1e-6, "euler x")
	assertClose(ey, 0.2, 1e-6, "euler y")
	assertClose(ez, 0.3, 1e-6, "euler z")
	assertClose(fx, 0.4, 1e-6, "fromEuler x")
	assertClose(fy, 0.5, 1e-6, "fromEuler y")
	assertClose(fz, 0.6, 1e-6, "fromEuler z")
	assertClose(ox, 0.7, 1e-6, "fromOrientation x")
	assertClose(oy, 0.8, 1e-6, "fromOrientation y")
	assertClose(oz, 0.9, 1e-6, "fromOrientation z")
	assertVector3Equal(lookAt.LookVector, 0, 0, -10)
end

function m.brickColorConstructorsAndEquality()
	assertEqual(BrickColor.new("Bright red"), BrickColor.Red())
	assertEqual(BrickColor.new(23), BrickColor.Blue())
	assertEqual(BrickColor.new("Unknown name"), BrickColor.new("Medium stone grey"))
	assertEqual(BrickColor.new(999999), BrickColor.new("Medium stone grey"))
	assertEqual(BrickColor.White().Color, Color3.fromRGB(242, 243, 243))
	assertEqual(tostring(BrickColor.Green()), "Dark green")
end

function m.brickColorPaletteClosestAndRandom()
	local closest = BrickColor.new(Color3.fromRGB(250, 10, 10))
	local paletteColor = BrickColor.palette(1)
	local randomColor = BrickColor.random()

	assertEqual(closest, BrickColor.new("Really red"))
	assert(paletteColor.Name ~= nil)
	assert(paletteColor.Number ~= nil)
	assert(randomColor.Name ~= nil)
	assertEqual(BrickColor.new(randomColor.Number), randomColor)
end

function m.instanceHierarchyAndLookup()
	local folder = Instance.new("Folder")
	local child = Instance.new("Part")
	local nested = Instance.new("ModuleScript")

	folder.Name = "Root"
	child.Name = "Child"
	child.Parent = folder
	nested.Name = "Nested"
	nested.Parent = child

	assertEqual(folder:FindFirstChild("Child"), child)
	assertEqual(folder.Child, child)
	assertEqual(child:GetFullName(), "Root.Child")
	assertEqual(nested:GetFullName(), "Root.Child.Nested")
	assert(child:IsA("Part"))
	assertEqual(#child:GetChildren(), 1)
	assertEqual(child:GetChildren()[1], nested)
end

function m.instanceRenameWaitAndDestroy()
	local folder = Instance.new("Folder")
	local child = Instance.new("ModuleScript")

	folder.Name = "Container"
	child.Name = "BeforeRename"
	child.Parent = folder
	child.Name = "AfterRename"

	assert(folder:FindFirstChild("BeforeRename") == nil)
	assertEqual(folder:FindFirstChild("AfterRename"), child)

	local waited = folder:WaitForChild("AutoCreated")
	assertEqual(waited.Name, "AutoCreated")
	assertEqual(waited.Parent, folder)
	assert(waited:IsA("ModuleScript"))

	child:Destroy()
	assert(folder:FindFirstChild("AfterRename") == nil)
	assert(child.Parent == nil)
	assertEqual(#child:GetChildren(), 0)
end

return m
