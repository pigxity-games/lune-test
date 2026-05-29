# Datatypes and Instances

The fake environment provides some Roblox datatypes and objects.

## Globals

The sandbox exposes:

- `BrickColor`
- `CFrame`
- `Color3`
- `Enum`
- `Instance`
- `Random`
- `UDim`
- `UDim2`
- `Vector2`
- `Vector3`

`Enum.SortDirection.Ascending` and `Enum.SortDirection.Descending` are available for fake MemoryStore sorted maps.

## Supported Instance Classes

The fake class table supports:

- `Instance`
- `DataModel`
- `Folder`
- `Model`
- `Tool`
- `Backpack`
- `Workspace`
- `BasePart`
- `Part`
- `SpawnLocation`
- `NumberValue`
- `RemoteEvent`
- `RemoteFunction`
- `Player`
- `Players`
- `RunService`
- `CollectionService`
- `MemoryStoreService`
- `ReplicatedStorage`
- `ServerScriptService`
- `StarterPlayer`
- `StarterPlayerScripts`
- `PlayerScripts`
- `ModuleScript`
- `LocalScript`

Service classes and other non-creatable classes are created by the environment, not through `Instance.new`.

```lua
local folder = Instance.new("Folder", workspace)
folder.Name = "Things"

local part = Instance.new("Part", folder)
part.Name = "Block"

assert(workspace.Things.Block == part)
assert(part:GetFullName() == "game.Workspace.Things.Block")
```

## Instance API

Fake instances support:

- `GetFullName()`
- `FindFirstChild(name)`
- `FindFirstChildOfClass(className)`
- `FindFirstChildWhichIsA(className, recursive)`
- `WaitForChild(name, timeout)`
- `GetChildren()`
- `GetDescendants()`
- `IsA(className)`
- `GetPropertyChangedSignal(propertyName)`
- `SetAttribute(attributeName, value)`
- `GetAttribute(attributeName)`
- `GetAttributeChangedSignal(attributeName)`
- `AddTag(tag)`
- `RemoveTag(tag)`
- `HasTag(tag)`
- `GetTags()`
- `Destroy()`
- `ClearAllChildren()`
- `Clone()`

Common signals include `Changed`, `ChildAdded`, `ChildRemoved`, `Destroying`, `AncestryChanged`, and `AttributeChanged`.

`BasePart` keeps `Position` and `CFrame` in sync. `NumberValue.Changed` fires with the new value when `Value` changes; other instances use the changed property name.

```lua
local value = Instance.new("NumberValue")
local changed

value.Changed:Connect(function(newValue)
	changed = newValue
end)

value.Value = 10
assert(changed == 10)
```

## RBXScriptSignal

Signals support:

- `Connect(listener)`
- `Fire(...)`
- `DisconnectAll()`
- `GetConnectionCount()`
- `GetDebugName()`

`:Connect` returns a `RBXScriptConnection` object.
Connections support `Disconnect()` and expose a `Connected` field.

```lua
local signal = RBXScriptSignal.new("Example")
local count = 0

local connection = signal:Connect(function()
	count += 1
end)

signal:Fire()
connection:Disconnect()
signal:Fire()

assert(count == 1)
```

## Vector2 and Vector3

`Vector2` supports `new`, `zero`, `one`, `xAxis`, `yAxis`, `Dot`, `Lerp`, arithmetic operators, equality, unary minus, and string conversion.

`Vector3` supports `new`, `zero`, `one`, `xAxis`, `yAxis`, `zAxis`, `Dot`, `Cross`, `Lerp`, arithmetic operators, equality, unary minus, and string conversion.

```lua
local a = Vector3.new(1, 2, 3)
local b = Vector3.new(4, 5, 6)

assert(a + b == Vector3.new(5, 7, 9))
assert(a:Dot(b) == 32)
```

## CFrame

`CFrame` supports:

- `CFrame.new(x, y, z)`
- `CFrame.new(vector3)`
- `CFrame.identity`
- `CFrame.lookAt(position, target)`
- `CFrame.Angles(x, y, z)`
- `CFrame.fromEulerAnglesXYZ(x, y, z)`
- `CFrame.fromOrientation(x, y, z)`
- `ToOrientation()`
- `ToEulerAnglesXYZ()`
- `Lerp(other, alpha)`
- `Inverse()`
- multiplication, addition, subtraction, equality, and string conversion

It only tracks position and stored orientation values. Operators are not performed on orientation.

## Color3

`Color3` supports:

- `Color3.new(r, g, b)`
- `Color3.fromRGB(r, g, b)`
- `Color3.fromHSV(h, s, v)`
- `ToHSV()`
- `Lerp(other, alpha)`
- `ToHex()`
- equality and string conversion

RGB components are clamped to `0..1`.

```lua
local color = Color3.fromRGB(255, 0, 128)
assert(color:ToHex() == "FF0080")
```

## UDim and UDim2

`UDim` supports `new`, addition, subtraction, equality, and string conversion.

`UDim2` supports:

- `UDim2.new(xScale, xOffset, yScale, yOffset)`
- `UDim2.fromScale(xScale, yScale)`
- `UDim2.fromOffset(xOffset, yOffset)`
- `Lerp(other, alpha)`
- addition, subtraction, equality, and string conversion

## BrickColor

`BrickColor` supports:

- `BrickColor.new(value)`
- `BrickColor.White()`
- `BrickColor.Gray()` / `BrickColor.Grey()`
- `BrickColor.Black()`
- `BrickColor.Red()`
- `BrickColor.Blue()`
- `BrickColor.Yellow()`
- `BrickColor.Green()`
- `BrickColor.random()`
- `BrickColor.palette(index)`
- `BrickColor.closest(color3)`
- equality and string conversion

Unknown names and numbers fall back to `Medium stone grey`.

## Random

`Random.new(seed)` returns a deterministic random object when a seed is provided.

Random objects support:

- `Clone()`
- `NextNumber(min, max)`
- `NextInteger(min, max)`
- `NextUnitVector()`
- `Shuffle(table)`

```lua
local random = Random.new(123)
local clone = random:Clone()

assert(random:NextInteger(1, 10) == clone:NextInteger(1, 10))
```
