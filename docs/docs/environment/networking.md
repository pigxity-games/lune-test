# Networking

The fake runtime supports Roblox-style `RemoteEvent` and `RemoteFunction` instances. They route calls between the server environment and fake client contexts created with `env:spawnClient()`.

Functions, threads, and instances outside the fake data model are replaced with `nil` for remote event arguments.

## RemoteEvent

`RemoteEvent` supports:

- `FireServer(...)`
- `FireClient(player, ...)`
- `FireAllClients(...)`
- `OnServerEvent`
- `OnClientEvent`

```lua
local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
remote.Name = "Ping"

local received
remote.OnServerEvent:Connect(function(player, value)
	received = { player = player, value = value }
end)

remote:FireServer("hello")

assert(received.player == game:GetService("Players").LocalPlayer)
assert(received.value == "hello")
```

A `LocalPlayer` is created automatically by default.

## RemoteFunction

`RemoteFunction` supports:

- `InvokeServer(...)`
- `InvokeClient(player, ...)`
- `OnServerInvoke`
- `OnClientInvoke`

```lua
local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
remote.Name = "Add"

remote.OnServerInvoke = function(player, a, b)
	return a + b
end

assert(remote:InvokeServer(2, 3) == 5)
```

`InvokeServer` errors when `OnServerInvoke` is not set. `InvokeClient` errors when the target player has no client handler.


## `addPlayer`

To create a fake Player instance, use `env:addPlayer(config)`. It returns a Player instance with a Character, Backpack, and PlayerScripts.

Config:

- `name`: string; defaults to a generated string.
- `userId`: number; defaults to a generated uid.
- `localPlayer`: boolean; if true, sets it as the environment's active local player and allows access through Players.LocalPlayer
- `createCharacter`: boolean; if true, creates a character model under workspace and assigns `Player.Character`
- `character`: Model; if not nil, uses this model as the character instead of a new one
- `runHooks`: boolean; defaults to true. If false, skips `Players.PlayerAdded` and `Player.CharacterAdded` hooks.

`OnClientEvent` and `OnClientInvoke` also function if `localPlayer = true`.

```lua
local player = env:addPlayer({
	name = "TestPlayer",
	localPlayer = true,
})

remote.OnClientInvoke = function(value)
	return value .. "!"
end

assert(remote:InvokeClient(player, "ready") == "ready!")
```

## Diagnostics

Remote calls are recorded on the environment and can be read with `env:inspectRemoteTraffic()`.

```lua
local env = getEnvironment()
local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
remote.Name = "LogMe"

remote:FireServer("payload")

local traffic = env:inspectRemoteTraffic()
assert(traffic[#traffic].kind == "FireServer")
assert(traffic[#traffic].remoteName == "LogMe")
```

`env:inspectRemoteTraffic()` records fake remote traffic for `RemoteEvent` and `RemoteFunction`.
