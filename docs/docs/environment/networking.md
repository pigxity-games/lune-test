# Networking

The fake runtime supports Roblox-style `RemoteEvent` and `RemoteFunction` instances. They route calls between the server environment and fake client Player instances.

Functions, threads, and instances outside the fake data model are replaced with `nil` in remote event arguments.

## RemoteEvent

`RemoteEvent` supports:

- `FireServer(...)`
- `FireClient(player, ...)`
- `FireAllClients(...)`
- `OnServerEvent`
- `OnClientEvent`

## RemoteFunction

`RemoteFunction` supports:

- `InvokeServer(...)`
- `InvokeClient(player, ...)`
- `OnServerInvoke`
- `OnClientInvoke`

## Client-to-Server

For these events, a `LocalPlayer` is created automatically by default.

RemoteEvent
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

RemoteFunction
```lua
local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
remote.Name = "Add"

remote.OnServerInvoke = function(player, a, b)
	return a + b
end

assert(remote:InvokeServer(2, 3) == 5)
```

`InvokeServer` errors when `OnServerInvoke` is not set. `InvokeClient` errors when the target player has no client handler.

## Creating players

Unlike client-to-server events, server-side event calls require player instances. To create a fake Player instance, use `env:addPlayer(config)`. It returns a Player instance with a Character, Backpack, and PlayerScripts.

Config:

- `name`: string; defaults to a generated string.
- `userId`: number; defaults to a generated user ID.
- `localPlayer`: boolean; if true, sets it as the environment's active local player and allows access through `Players.LocalPlayer`. Overrides the default `LocalPlayer`.
- `createCharacter`: boolean; if true, creates a character model under `workspace` and assigns `Player.Character`.
- `character`: Model; if not `nil`, uses this model as the character instead of a new one.
- `runHooks`: boolean; defaults to true. If false, skips `Players.PlayerAdded` and `Player.CharacterAdded` hooks.

## Server-to-Client

### Single-player events

If you only need to test events with one player, simply use `OnClientEvent` or `OnClientInvoke` with a player that has `localPlayer = true`.

```lua
local player = env:addPlayer({
    name = "Player",
    localPlayer = true
})

local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))
local n = 0

remote.OnClientEvent:Connect(function(player, value)
    n += 1
end)

remote:FireClient(player)
assert(n == 1)
```

### Multi-player events

`LocalPlayer` cannot be used for multi-player tests. Thus, you must bind the event to each player object manually. The fake signal API exposes a `ConnectPlayer` method, which allows for different handlers for each player. Note that this method does not exist in the real Roblox API.

```lua
local player1 = env:addPlayer({
    name = "Player1"
})

local player2 = env:addPlayer({
    name = "Player2"
})

local player1Count = 0
local player2Count = 0

local remote = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage"))

remote.OnClientEvent:ConnectPlayer(player1, function(num)
    player1Count += num
end)
remote.OnClientEvent:ConnectPlayer(player2, function(num)
    player2Count += num
end)

remote:FireClient(player1, 1)
remote:FireClient(player2, 3)

assert(player1Count == 1)
assert(player2Count == 3)
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
