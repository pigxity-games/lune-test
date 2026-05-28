# Scheduler

Each environment owns a fake scheduler. The `task` global is bound to that scheduler, which makes scheduled work deterministic in tests.

```lua
local env = getEnvironment()

local done = false

task.delay(1, function()
	done = true
end)

env.scheduler:advance(0.5)
assert(done == false)

env.scheduler:advance(0.5)
assert(done == true)
```

## task API

The sandboxed `task` global supports:

- `task.spawn(callback, ...)`
- `task.defer(callback, ...)`
- `task.delay(seconds, callback, ...)`
- `task.wait(seconds)`
- `task.cancel(handle)`

`spawn` creates a managed coroutine and queues it immediately. `defer` queues a callback for the current scheduler time. `delay` queues a callback for a later scheduler time.

```lua
local order = {}

task.defer(function()
	table.insert(order, "defer")
end)

task.spawn(function()
	table.insert(order, "spawn")
end)

getEnvironment().scheduler:flush()

assert(#order == 2)
```

`task.cancel(handle)` marks a queued handle as cancelled. Cancelled items are skipped when the scheduler flushes.

## Waiting

`task.wait(seconds)` can only yield inside a scheduler-managed thread. Use `task.spawn` when testing yielding code directly.

```lua
local env = getEnvironment()
local finished = false

task.spawn(function()
	task.wait(2)
	finished = true
end)

env.scheduler:advance(1)
assert(finished == false)

env.scheduler:advance(1)
assert(finished == true)
```

Top-level script execution cannot yield through the fake scheduler. A top-level `task.wait` raises an error instead of suspending the runner.

## Advancing Time

The scheduler object supports:

- `scheduler:flush()`: runs queued work whose scheduled time is less than or equal to the current time.
- `scheduler:advance(delta)`: moves fake time forward and flushes ready work.
- `scheduler:runAll()`: runs all queued work, advancing time to each pending item as needed.
- `scheduler:now()`: returns current fake time.
- `scheduler:inspect()`: returns queued item summaries.
- `scheduler:canYieldCurrentThread()`: returns whether the current coroutine is scheduler-managed.

When time advances by a positive amount, the environment fires `RunService.Heartbeat`, `RunService.Stepped`, and `RunService.RenderStepped`.

## WaitForChild

`Instance:WaitForChild(name, timeout)` uses the scheduler when called from a managed thread. It returns immediately if the child exists, returns the child when a matching `ChildAdded` signal fires, or returns `nil` on timeout.

```lua
local env = getEnvironment()
local folder = Instance.new("Folder", workspace)
local found

task.spawn(function()
	found = folder:WaitForChild("Child", 1)
end)

task.defer(function()
	local child = Instance.new("Folder", folder)
	child.Name = "Child"
end)

env.scheduler:runAll()
assert(found == folder.Child)
```

Outside a managed thread, `WaitForChild` returns `nil` when the child is missing.
