# Runtime Reference

This document describes the fake Roblox runtime currently exposed by `lune-test`. It reflects the current implementation in `src/fake/` and the current regression suite in `test/fixture-main/test_fake_runtime.lua`.

## Overview

The runtime can be used in two ways:

- Indirectly through the sandbox used by test manifests and script execution.
- Directly through the createEnvironment global.

The fake module exports:

- `createEnvironment(config)`
- `getEnvironment()`
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

Sandbox globals also expose those fake-module exports plus `Enum.SortDirection`.

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

Installed sandbox environments also support:

- `env:configure(config)`
- `env:reset(config?)`
- `env:overrideService(serviceName, override)`
- `env:install()`
- `env:uninstall()`

The environment is stateful. If you want fresh state between tests, create a new environment or call `env:reset(...)`.

Within the test runner, each case and each script selection gets a fresh sandbox and a fresh fake runtime instance.

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

If you provide `activePlayers` with `isClient = true` and do not mark any player with `localPlayer = true`, the first created player becomes `Players.LocalPlayer`.

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
- `TeleportOptions`

This is not a complete Roblox class set. Only the classes listed above are implemented.

These supported service classes are intentionally not creatable through public `Instance.new(...)`:

- `DataModel`
- `RunService`
- `CollectionService`
- `MemoryStoreService`
- `TeleportService`
- `ReplicatedStorage`
- `ServerScriptService`
- `StarterPlayer`
- `StarterPlayerScripts`
- `PlayerScripts`

Use `game:GetService(...)` to access those services. `StarterPlayerScripts` and `PlayerScripts` are created internally when the runtime mounts client code or player containers.

## Core Instance Behavior

Instances support:

- `Name`
- `Parent`
- `ClassName`
- `GetFullName()`
- `FindFirstChild(name)`
- `FindFirstChildOfClass(className)`
- `FindFirstChildWhichIsA(className, recursive?)`
- `WaitForChild(name, timeout?)`
- `GetChildren()`
- `GetDescendants()`
- `IsA(className)`
- `Destroy()`
- `ClearAllChildren()`

`game` additionally supports:

- `GetService(serviceName)`
- `FindService(serviceName)`

The fake `DataModel` also exposes:

- `PrivateServerId`
- `PrivateServerOwnerId`
- `ReservedServerAccessCode`

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

Supported tag helpers on runtime-backed instances:

- `AddTag(tag)`
- `RemoveTag(tag)`
- `HasTag(tag)`
- `GetTags()`

Signal payloads currently follow the fake implementation rather than the full Roblox API:

- `Changed` fires the property name for most classes.
- `NumberValue.Changed` fires the new numeric value.
- `ChildAdded` and `ChildRemoved` fire the child instance.
- `AncestryChanged` fires `self, newParent`.
- `AttributeChanged` fires the attribute name.
- `GetAttributeChangedSignal(name)` currently fires the new attribute value.
- `GetPropertyChangedSignal(name)` currently fires the new property value.

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
- Returns `nil` if the instance has no scheduler-backed runtime attached.
- Returns `nil` if the current execution context cannot yield, such as top-level sandbox execution.

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
Fresh parts start at `Position = Vector3.zero` and `CFrame = CFrame.new(Vector3.zero)`.

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

- `Heartbeat(deltaTime)` fires on `advance(delta)`
- `Stepped(currentTime, deltaTime)` fires on `advance(delta)`
- `RenderStepped(deltaTime)` fires on `advance(delta)`

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
- Tags remain attached to the instance even if it leaves the DataModel.
- `GetTagged(tag)` only returns tagged instances currently inside the DataModel.
- Reparenting into or out of the DataModel fires the added or removed tag signals as membership changes.
- Runtime-backed instances can call the same tag operations directly through `instance:AddTag(...)`, `instance:RemoveTag(...)`, `instance:HasTag(...)`, and `instance:GetTags()`.

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

Current behavior:

- `env:addPlayer({ localPlayer = true })` also assigns that player to `Players.LocalPlayer`.
- Every added player gets a `Backpack` and `PlayerScripts` container.
- `env:removePlayer(player)` fires `PlayerRemoving`, destroys the player's current character if present, and clears `LocalPlayer` if that player was local.
- `env:replaceCharacter(player, characterConfig?)` parents the new character into `Workspace`.

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
- `SetAsync(key, value, expirationSeconds?, sortKey?)`
- `UpdateAsync(key, transform, expirationSeconds?)`
- `RemoveAsync(key)`
- `GetRangeAsync(sortDirection, count?)`
- `ListItemsAsync()`

Queue operations:

- `AddAsync(value, expirationSeconds?, priority?)`
- `ReadAsync(count?, allOrNothing?, waitTimeout?)`
- `RemoveAsync(reservationId)`
- `GetSizeAsync(excludeInvisible?)`

Current behavior:

- Expiry is based on fake scheduler time.
- `GetAsync` returns `value, sortKey` when a value exists.
- `UpdateAsync` receives `oldValue, oldSortKey` and may return `newValue, newSortKey`.
- `GetRangeAsync` sorts by `sortKey` when present and falls back to key ordering for ties or missing sort keys.
- Queue reads reserve items and return `values, reservationId`.
- Queue priority is higher-first, then FIFO for equal priority.
- `GetQueue(name, invisibilityTimeoutSeconds?)` supports visibility timeouts for reserved items.
- Invisible reserved items are excluded from `GetSizeAsync(true)` and become visible again when the reservation expires.
- `RemoveAsync(reservationId)` only removes items that are still reserved under that reservation id.
- `UpdateAsync` can cancel a write by returning `nil`, leaving the existing stored value unchanged.

### `TeleportService`

Supported surface:

- `PrivateServerId`
- `PrivateServerOwnerId`
- `ReservedServerAccessCode`
- `TeleportAsync(placeId, players, options?)`
- `ReserveServerAsync(placeId)`
- `ReserveServer(placeId)`
- `GetLocalPlayerTeleportData()`

`TeleportAsync` stores per-player teleport data when `options.TeleportData` is supplied.
`ReserveServerAsync` also updates `game.ReservedServerAccessCode` and `TeleportService.ReservedServerAccessCode` in the active environment.

`TeleportOptions` currently supports:

- `ReservedServerAccessCode`
- `SetTeleportData(data)`
- `GetTeleportData()`

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
- Function and thread arguments are sanitized to `nil`.
- Fake instances outside the DataModel are sanitized to `nil` when sent through remotes.
- Remote logs from `env:inspectRemoteTraffic()` include `FireServer`, `FireClient`, `InvokeServer`, `InvokeClient`, and `TeleportAsync` entries.

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
- Invocation arguments use the same sanitizing rules as `RemoteEvent`.

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
- `client.game:GetService("Players")` returns a proxy with that client's own `LocalPlayer`, while other services are shared fake service instances.

## Diagnostics

Environment diagnostics:

- `env:inspectTree(root?)`
- `env:inspectTasks()`
- `env:inspectSignals()`
- `env:inspectRemoteTraffic()`

These are intended for debugging fake-runtime behavior in tests.

- `inspectTree(root?)` returns a formatted string tree.
- `inspectTasks()` returns the scheduler's queued task snapshot.
- `inspectSignals()` returns `{ name, connections }` records.
- `inspectRemoteTraffic()` returns shallow copies of logged remote and teleport records.

## Sandbox Integration

Sandbox globals include:

- `game`
- `workspace`
- fake datatype globals like `Vector3`, `CFrame`, `Color3`, `UDim2`, and `BrickColor`
- `Instance`
- `createEnvironment`
- `getEnvironment`
- `Environment`
- `Signal`
- `Scheduler`
- `Random`
- `task`
- created services such as `ReplicatedStorage`, `Players`, and `Workspace`
- `LocalPlayer` when the active environment has one

Special mount behavior currently implemented:

- a `PlayerScripts` mount is exposed through `Players.LocalPlayer.PlayerScripts`
- the same mount is also mirrored under `StarterPlayer.StarterPlayerScripts`

Mounted module trees are lazily projected into fake instances and support Roblox-style requires through the sandbox.

Sandbox switching behavior:

- `env:install()` swaps the active sandbox globals to that environment.
- `env:uninstall()` restores the base sandbox environment.
- uninstalling a non-active environment errors
- uninstalling the base environment errors
- custom globals added while one environment is active are preserved with that environment when switching away and back

## Current Scope And Non-Goals

The fake runtime intentionally does not emulate all of Roblox.

Current limitations include:

- no full physics engine
- no full replication model
- no complete Roblox service catalog
- no complete class/property/method catalog
- no real networking

When a service or instance type is not supported, the runtime should fail with a precise error rather than silently approximating unrelated behavior.
