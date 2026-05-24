# Runtime Reference

This document describes the fake Roblox runtime currently exposed by `lune-test`. It reflects the current implementation in `src/fake/` and the current regression suite in `test/fixture-main/test_fake_runtime.lua`.

## Overview

The runtime can be used in two ways:

- Indirectly through the sandbox used by test manifests and script execution.
- Directly through the createEnvironment global.

The fake module exports:

- `createEnvironment(config)`
- `Environment`
- `Instance`
- `Signal`
- `Scheduler`
- `Color3`
- `Vector2`
- `Vector3`
- `CFrame`
- `UDim`
- `UDim2`
- `BrickColor`
- `Random`

## Creating An Environment

Create a standalone fake runtime:

```lua
local env = createEnvironment({
	isStudio = true,
	isServer = true,
	isClient = true,
	activePlayers = {},
})
```

The returned environment includes:

- `env.game`
- `env.globals`
- `env.Instance`
- `env.task`
- `env.scheduler`

The environment is stateful. If you want fresh state between tests, create a new environment or call `env:reset(...)`.

## Configuration

`createEnvironment(config)` accepts these runtime options:

- `isStudio`
- `isServer`
- `isClient`
- `privateServerId`
- `privateServerOwnerId`
- `reservedServerAccessCode`
- `teleportData`
- `availableServices`
- `availableInstanceTypes`
- `activePlayers`
- `localPlayerName`
- `localPlayerUserId`
- `createDefaultCharacter`
- `nextUserId`
- `persistenceAdapters`
- `serviceOverrides`

### Defaults

If you omit `availableServices`, the runtime enables the built-in default service set:

- `CollectionService`
- `MemoryStoreService`
- `Players`
- `ReplicatedStorage`
- `RunService`
- `ServerScriptService`
- `StarterPlayer`
- `TeleportService`
- `Workspace`

If you omit `availableInstanceTypes`, the runtime enables every currently supported fake class from `src/fake/ClassData.lua`.

If you omit `activePlayers` and `isClient` is `true`, the runtime creates a default local player.

### Restricting Services Or Types

You can limit what a suite or standalone environment can access:

```lua
local env = createEnvironment({
	availableServices = {
		"RunService",
		"Workspace",
	},
	availableInstanceTypes = {
		"DataModel",
		"Folder",
		"Instance",
		"RunService",
		"Workspace",
	},
	activePlayers = {},
})
```

Unsupported access produces actionable errors that list the available services or enabled types.

### Overriding Service Behavior

Service overrides can be passed at construction time or applied later:

```lua
local env = createEnvironment({
	serviceOverrides = {
		RunService = {
			IsStudio = function()
				return false
			end,
		},
	},
})

env:overrideService("Workspace", {
	CustomMarker = "override",
})
```

## Supported Instance Classes

The fake runtime currently supports these classes:

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
- `TeleportService`
- `ReplicatedStorage`
- `ServerScriptService`
- `StarterPlayer`
- `StarterPlayerScripts`
- `PlayerScripts`
- `ModuleScript`
- `LocalScript`

This is not a complete Roblox class set. Only the classes listed above are implemented.

## Core Instance Behavior

Instances support:

- `Name`
- `Parent`
- `ClassName`
- `GetFullName()`
- `FindFirstChild(name)`
- `FindFirstChildOfClass(className)`
- `WaitForChild(name, timeout?)`
- `GetChildren()`
- `GetDescendants()`
- `IsA(className)`
- `Destroy()`
- `ClearAllChildren()`

Supported built-in signals on every instance:

- `Changed`
- `ChildAdded`
- `ChildRemoved`
- `Destroying`
- `AncestryChanged`
- `AttributeChanged`

Supported signal helpers:

- `GetPropertyChangedSignal(propertyName)`
- `GetAttributeChangedSignal(attributeName)`

Supported attribute helpers:

- `SetAttribute(name, value)`
- `GetAttribute(name)`

### Parenting Rules

Parenting updates the child lists and named lookup tables immediately.

- Reparenting removes the instance from the old parent and adds it to the new one.
- Recursive parenting is rejected. An instance cannot be parented under one of its descendants.
- Destroying an instance destroys its descendants first, then disconnects its owned signals.

### `WaitForChild`

`WaitForChild(name, timeout?)` behaves as follows:

- Returns immediately if the child already exists.
- Uses the environment scheduler when the child does not yet exist.
- Returns `nil` on timeout.
- Errors if used on an instance that has no scheduler-backed runtime attached.

## Built-In Class Properties

The fake runtime includes a small set of class defaults:

- `Tool`
  - `RequiresHandle = false`
  - `Enabled = true`
- `BasePart`
  - `Anchored = false`
  - `CanCollide = true`
  - `Transparency = 0`
- `SpawnLocation`
  - `Neutral = true`
- `NumberValue`
  - `Value = 0`
- `Player`
  - `UserId = 0`
  - `AccountAge = 0`
  - `MembershipType = "None"`

### BasePart

`BasePart` currently supports predictable data-only world state:

- `Position`
- `CFrame`
- `Anchored`
- `CanCollide`
- `Transparency`

Updating `Position` also updates `CFrame`. Updating `CFrame` also updates `Position`.

This runtime does not provide full physics simulation.

## Signals

Signals are implemented by `src/fake/Signal.lua`.

Supported operations:

- `signal:Connect(listener)`
- `connection:Disconnect()`
- `signal:Fire(...)`
- `signal:DisconnectAll()`
- `signal:GetConnectionCount()`
- `signal:GetDebugName()`

Signal behavior currently guaranteed by tests:

- Disconnected listeners do not fire again.
- Disconnecting one listener during an active fire prevents later listeners in the same emission if they were disconnected before their turn.
- `DisconnectAll()` clears every active connection.

## Scheduler And `task`

Each environment owns a deterministic scheduler and exposes a fake `task` library:

- `task.spawn`
- `task.defer`
- `task.delay`
- `task.wait`
- `task.cancel`

Scheduler helpers:

- `env.scheduler:flush()`
- `env.scheduler:advance(deltaSeconds)`
- `env.scheduler:runAll()`
- `env.scheduler:now()`
- `env:inspectTasks()`

### Current Scheduler Semantics

The scheduler is deterministic and manual:

- `flush()` runs work scheduled for the current time.
- `advance(delta)` moves fake time forward and then flushes due work.
- `runAll()` advances until no queued work remains.
- Negative delays are clamped to `0`.
- Cancelled callbacks remain skipped.
- `task.wait(n)` resumes the coroutine after `n` fake seconds.

`RunService` integrates with scheduler stepping:

- `Heartbeat` fires on `advance(delta)`
- `Stepped` fires on `advance(delta)`
- `RenderStepped` fires on `advance(delta)`

## Services

### `RunService`

Built-in behavior:

- `IsStudio()`
- `IsServer()`
- `IsClient()`
- `Heartbeat`
- `Stepped`
- `RenderStepped`

### `CollectionService`

Supported operations:

- `AddTag(instance, tag)`
- `RemoveTag(instance, tag)`
- `HasTag(instance, tag)`
- `GetTagged(tag)`
- `GetInstanceAddedSignal(tag)`
- `GetInstanceRemovedSignal(tag)`

Current behavior:

- Duplicate tags are suppressed.
- Tag order is stable in insertion order.
- Destroying a tagged instance removes it from tag state and fires removed signals.
- Reparenting does not remove tags by itself.

### `Players`

Supported surface:

- `Players.LocalPlayer`
- `Players:GetPlayers()`
- `Players:GetPlayerByUserId(userId)`
- `Players.PlayerAdded`
- `Players.PlayerRemoving`

Player instances include:

- `Backpack`
- `PlayerScripts`
- `Character`
- `CharacterAdded`
- `CharacterRemoving`
- `LoadCharacter()`

Environment helpers:

- `env:addPlayer(config)`
- `env:removePlayer(player)`
- `env:assignLocalPlayer(player)`
- `env:replaceCharacter(player, characterConfig?)`
- `env:getPlayers()`

### `Workspace`

`Workspace` is available as both:

- `game:GetService("Workspace")`
- the lowercase global `workspace`

It is a data container within the fake data model. No full physics behavior is implemented.

### `MemoryStoreService`

Supported primitives:

- `GetSortedMap(name)`
- `GetQueue(name)`
- `SetAdapter(name, adapter)`
- `GetAdapter(name)`

Sorted map operations:

- `GetAsync(key)`
- `SetAsync(key, value, expirationSeconds?)`
- `UpdateAsync(key, transform, expirationSeconds?)`
- `RemoveAsync(key)`
- `ListItemsAsync()`

Queue operations:

- `AddAsync(value)`
- `ReadAsync(count?)`
- `GetSizeAsync()`

Current behavior:

- Expiry is based on fake scheduler time.
- Queue reads are destructive FIFO reads.
- `UpdateAsync` can remove a key by returning `nil`.

### `TeleportService`

Supported surface:

- `PrivateServerId`
- `PrivateServerOwnerId`
- `ReservedServerAccessCode`
- `TeleportAsync(placeId, players, options?)`
- `ReserveServer(placeId)`
- `GetLocalPlayerTeleportData()`

`TeleportAsync` stores per-player teleport data when `options.TeleportData` is supplied.

### Other Default Services

These default services are exposed as fake instances but do not currently implement extra behavior beyond instance/container semantics:

- `ReplicatedStorage`
- `ServerScriptService`
- `StarterPlayer`

## Remotes

### `RemoteEvent`

Supported server-side and client-side operations:

- `FireServer(...)`
- `FireClient(player, ...)`
- `FireAllClients(...)`
- `OnServerEvent`
- `OnClientEvent`

Current behavior:

- Server inbound calls inject the calling player as the first server argument.
- `FireClient` requires an explicit player.
- `FireAllClients` iterates over the current player list.
- Remote traffic is logged for diagnostics.

### `RemoteFunction`

Supported operations:

- `InvokeServer(...)`
- `InvokeClient(player, ...)`
- `OnServerInvoke`
- `OnClientInvoke`

Current behavior:

- Server inbound invocation injects the calling player as the first server argument.
- Client invoke handlers can be registered per spawned client.
- Missing invoke handlers produce explicit errors.

## Client/Server Pairing

The runtime can emulate a server plus multiple lightweight clients inside one process.

Use:

- `env:spawnClient(config)`

Returned client objects include:

- `client.LocalPlayer`
- `client.game`
- `client.globals`
- `client:bindRemote(remote)`

Behavior:

- Clients share the same replicated object tree.
- Each client gets its own `Players.LocalPlayer`.
- Client remote bindings allow per-player `FireServer`, `InvokeServer`, `OnClientEvent`, and `OnClientInvoke`.

## Diagnostics

Environment diagnostics:

- `env:inspectTree(root?)`
- `env:inspectTasks()`
- `env:inspectSignals()`
- `env:inspectRemoteTraffic()`

These are intended for debugging fake-runtime behavior in tests.

## Sandbox Integration

Sandbox globals include:

- `game`
- fake datatype globals like `Vector3`, `CFrame`, `Color3`, `UDim2`, and `BrickColor`
- `Instance`
- `task`
- created services such as `ReplicatedStorage`, `Players`, and `Workspace`

Special mount behavior currently implemented:

- a `PlayerScripts` mount is exposed through `Players.LocalPlayer.PlayerScripts`
- the same mount is also mirrored under `StarterPlayer.StarterPlayerScripts`

Mounted module trees are lazily projected into fake instances and support Roblox-style requires through the sandbox.

## Passing Runtime Config Through Test Suites

The runner currently forwards `testData.environment` into the sandbox runtime for a suite, and `selection.environment` for script selections.

That means a suite can provide environment config alongside its normal test metadata if you are constructing manifests programmatically or extending manifest data in-repo.

## Current Scope And Non-Goals

The fake runtime intentionally does not emulate all of Roblox.

Current limitations include:

- no full physics engine
- no full replication model
- no complete Roblox service catalog
- no complete class/property/method catalog
- no real networking

When a service or instance type is not supported, the runtime should fail with a precise error rather than silently approximating unrelated behavior.
