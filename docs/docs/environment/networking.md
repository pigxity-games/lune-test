# Networking

The fake runtime supports `RemoteEvent` and `RemoteFunction` instances. They route calls between the server environment and fake client contexts created with `env:spawnClient()`.

Remote arguments are sanitized before delivery. Functions, threads, and instances outside the fake data model are replaced with `nil`.

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

`FireServer` requires a `LocalPlayer`. In the default client-capable environment, one is created automatically.

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

## Client Contexts

Use `env:spawnClient(config)` to make a player-bound client context. The returned table contains:

- `LocalPlayer`: the client player.
- `game`: a proxy whose `Players` service has that client as `LocalPlayer`.
- `globals`: a global table for the client context.
- `bindRemote(remote)`: returns a player-bound remote proxy.

```lua
local env = getEnvironment()
local client = env:spawnClient({
	name = "SecondPlayer",
})

local remote = Instance.new("RemoteFunction", game:GetService("ReplicatedStorage"))
remote.Name = "ClientQuestion"

local clientRemote = client:bindRemote(remote)
clientRemote.OnClientInvoke = function(value)
	return value .. "!"
end

assert(remote:InvokeClient(client.LocalPlayer, "ready") == "ready!")
```

A bound remote uses that client's player for `FireServer` and `InvokeServer`, and it exposes a client-specific `OnClientEvent` signal.

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

`TeleportService:TeleportAsync` is also recorded in the same traffic log.
