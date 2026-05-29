# Environment API
An environment represents the state of the fake Roblox runtime. Every test suite and script automatically runs in its own environment, which is what allows access to globals such as `game`.

The runner exposes two custom globals: `getEnvironment`, which could be used to obtain the current environment, and `createEnvironment`, which creates an entirely seperate environment.

An environment object has the following fields:

- `globals`: a list of globals which would be injected into `getfenv` on environment install. This includes Roblox defaults such as `game` and `workspace`, but not luau-native globals, such as `require`.
- `game`: the fake `DataModel`.
- `Instance`: the environment-bound `Instance` factory.
- `task`: the environment-bound task library.
- `scheduler`: the fake scheduler used by `task`.

```lua
local env = getEnvironment()

local part = Instance.new("Part", workspace)
part.Name = "Part"
assert(part == env.game:GetService("Workspace").Part)
```

## Configuring
The best way to modify an environment's settings is to configure it. This method accepts a table, which merges data with current settings. If the environment is active, config is also automatically applied.

`createEnvironment` and `configure` allow specifying a config table. The table has the following options:

- `availableServices`: a set of service names accessible through `game:GetService("...")`. By default, all built-in services are set to `true`. All keys in `serviceOverrides` are also implicitly `true`.
- `serviceOverrides`: allows specifying overrides to specific service methods/fields without mutating the entire service table. Adding a new entry adds a new custom service.
- `datamodel`: a table which allows specifying custom fields for the datamodel, like `game.myField`.
- `globals`: allows specifying custom globals for the environment without overriding default globals.

You may obtain the current configuration from the `.config` property, but that table is frozen and can only be modified via `:configure`.

```lua
local env = getEnvironment()

local counter = 0

env:configure({
    availableServices = {
        RunService = false,
    },
    serviceOverrides = {
        MyCustomService = {
            increment = function()
                counter += 1
            end
        },
    },
    globals = {
        myGlobal = "Test"
    }
})

assert(game:GetService("ReplicatedStorage") ~= nil) --other services are still available
assert(game:GetService("RunService") == nil)

game:GetService("MyCustomService").increment()
assert(counter == 1)

assert(myGlobal == "Test")
``` 

`configure` merges environment config into the active environment and refreshes globals, data model fields, service availability, and service overrides immediately.

## Installing an Environment
Creating a new environment or modifying the global table directly does not sync globals with the environment state. To set an environment as active, run the `:install()` method. This sets global values under `globals` as actual globals in the sandbox.

```lua
local env = getEnvironment()

env.globals.myGlobal = "Hello"

assert(env.globals.myGlobal == "Hello")
assert(myGlobal == nil)

env:install()
assert(myGlobal == "Hello")

local env2 = createEnvironment({
    globals = {
        myGlobal = "Test"
    }
})

env2:install()
assert(myGlobal == "Test")

env2:uninstall()
assert(myGlobal == "Hello")
```

Custom global values in _G are also bound to environment state.

## Environment Methods

- `Environment.new(config)`: creates an environment. In tests, prefer the global `createEnvironment(config)`.
- `Environment.getActiveEnvironment()`: returns the active environment. In tests, prefer the global `getEnvironment()`.
- `env:getService(name)`: returns a fake service or errors if the service is unavailable.
- `env:addPlayer(config)`: creates a fake `Player`, parents it to `Players`, and fires lifecycle signals unless `runHooks = false`.
- `env:assignLocalPlayer(player)`: sets `Players.LocalPlayer` and the `LocalPlayer` global.
- `env:getPlayers()`: returns a copy of the active players array.
- `env:removePlayer(player)`: fires removal signals, destroys the player character, and removes the player.
- `env:replaceCharacter(player, characterConfig, runHooks)`: replaces `player.Character`.
- `env:overrideService(serviceName, override)`: applies or replaces a service override.
- `env:configure(config)`: merges config into the live environment and refreshes globals, datamodel fields, and service availability.
- `env:reset(config)`: replaces the environment state while keeping the same active environment object.
- `env:install()` / `env:uninstall()`: swap the active environment in the current sandbox.
- `env:inspectTree(root)`: returns a string tree of fake instances.
- `env:inspectTasks()`: returns queued scheduler items.
- `env:inspectSignals()`: returns signal names and connection counts.
- `env:inspectRemoteTraffic()`: returns recorded remote calls.

## Related Pages

- [Services](./services)
- [Scheduler](./scheduler)
- [Networking](./networking)
- [Datatypes](./datatypes)
