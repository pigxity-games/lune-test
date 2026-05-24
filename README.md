# lune-test
A test runner for the Lune runtime that simulates enough of the Roblox environment to run unit tests and sandboxed scripts with Roblox-style globals and requires.

Detailed fake runtime documentation is under [RUNTIME.md](./RUNTIME.md).

It supports:
- Roblox instance-based requires
- fake Roblox globals like `game`, `Instance`, `Vector3`, `Color3`, and more
- manifest composition with child manifests
- multiple workspaces
- Rojo-derived mounts
- test auto-discovery with globs
- running plain Lua/Luau scripts in the same sandboxed environment

## Installation
- Download the bundled Lua file from GitHub releases
- Place it in `~/.lune` for easy execution

Or build it from source:

```sh
git clone https://github.com/pigxity-games/lune-test
cd lune-test
rokit install
darklua process src/main.lua dist/lune-test.luau
```

## CLI usage
By default, `lune-test` looks for `test/manifest.lua`.

```sh
lune run src/main.lua
```

You can provide a manifest explicitly with `-m` or `--manifest`:

```sh
lune run src/main.lua --manifest test/manifest.lua
```

The first positional argument is a comma-separated list of selections. Each selection may be:
- a test suite name from the manifest
- a path to a `.lua` or `.luau` file to run as a sandboxed script

Examples:

```sh
lune run src/main.lua test_runner_core
lune run src/main.lua test/fixture-main/scripts/uses_modules.lua
lune run src/main.lua test_runner_core,test/multi-workspace/scripts/game_script.lua --workspace game
```

When running scripts:
- each script runs in its own sandbox
- the closest manifest is selected automatically by walking parent directories upward
- if the selected manifest only defines workspaces, `lune-test` tries to infer the workspace from the script path
- you can override workspace selection with `-w` or `--workspace`

```sh
lune run src/main.lua test/multi-workspace/scripts/game_script.lua
lune run src/main.lua test/multi-workspace/scripts/game_script.lua --workspace game
```

Script-only runs do not print `[TEST]`, `[PASS]`, or `TEST RESULTS`. Mixed script plus suite runs still use the normal reporter output.

## Manifest format
A manifest is a Lua file that returns a table.

Basic example:

```lua
return {
	tests = {
		test_runner_core = {
			module = "./test_runner_core",
			cases = {
				caseArgumentsArePassedThrough = { 7, 3, 4 },
				singleLiteralCaseArgumentIsPassedThrough = "hello",
				lazyTableCaseArgumentsArePassedThrough = function()
					return { 9, 4, 5 }
				end,
			},
		},
	},
	mounts = {
		ReplicatedStorage = "./src/shared",
		ServerScriptService = "./src/server",
		PlayerScripts = "./src/client",
	},
}
```

Each `cases` value is passed to the named test function as positional arguments:
- `{ "hello", 123 }` becomes `testCase("hello", 123)`
- `"single value"` becomes `testCase("single value")`
- a function value is evaluated lazily at runtime and then normalized the same way

## Manifest path rules
For `mounts`, `childManifests`, `rojoProject`, and `testLocations`:
- paths starting with `./` are resolved relative to the manifest file
- paths without `./` are resolved from the current working directory
- absolute paths are used as-is

Examples:

```lua
mounts = {
	ReplicatedStorage = "./src/shared", -- relative to this manifest
	ServerScriptService = "test/project/src/server", -- relative to cwd
}
```

Rojo `$path` entries are still resolved relative to the Rojo project file itself.

## Child manifests
You can compose multiple manifests together:

```lua
return {
	childManifests = {
		"./fixture-main/manifest",
		"test/multi-workspace/manifest",
	},
}
```

## Workspaces
Workspaces let one manifest define multiple mount layouts.

```lua
return {
	workspaces = {
		hub = {
			rojoProject = "test/multi-workspace/hub.project.json",
		},

		game = {
			mounts = {
				ReplicatedStorage = {
					_root = "./src/game/shared",
					Common = "./src/common/shared",
				},
				ServerScriptService = {
					Game = "./src/game/server",
					Utils = "test/multi-workspace/src/game/utils",
				},
			},
		},
	},

	tests = {
		game_tests = {
			workspace = "game",
			module = "./game_tests",
			cases = {
				workspaceGameRequires = {},
			},
		},
	},
}
```

If a suite sets `workspace`, it uses that workspace's mounts. Otherwise it uses the manifest-level `mounts`.

## Nested mounts
Nested mount tables let you mount children inside a service:

```lua
mounts = {
	ReplicatedStorage = {
		Common = "src/common/shared",
	},
	ServerScriptService = {
		Game = "src/game/server",
	},
}
```

You can also mount the node itself with `_root`:

```lua
mounts = {
	ReplicatedStorage = {
		_root = "src/shared",
		Common = "src/common/shared",
	},
}
```

## Rojo workspaces
`rojoProject` can be used instead of `mounts`:

```lua
workspaces = {
	hub = {
		rojoProject = "./hub.project.json",
	},
}
```

The loader reads `$path` entries from the Rojo tree and turns them into mounts automatically.

`StarterPlayer/StarterPlayerScripts` is exposed in the sandbox as `Players.LocalPlayer.PlayerScripts`.

## Auto-discovery with `testLocations`
You can discover tests from file globs instead of listing them manually:

```lua
return {
	testLocations = {
		"./unit1/*",
		"./unit2/**",
	},
}
```

Rules:
- only `.lua` and `.luau` files are included
- `*` matches within one path segment
- `**` matches recursively
- each discovered module becomes a suite
- exported functions in the module are treated as test cases
- non-function exports are ignored

For example, `test/auto-discovery/unit1/test1.lua` becomes the suite `unit1/test1`.

## Script mode
If the positional selection is a `.lua` or `.luau` file, it is run as a script inside a sandbox with Roblox globals and requires enabled.

That means scripts like this work:

```lua
local SomeGameModule = require(ServerScriptService.Game.SomeGameModule)
local SharedGameModule = require(ServerScriptService.Utils.SharedGameModule)

assert(SomeGameModule.add(8, 3) == 11)
assert(SharedGameModule.average(10, 6) == 8)
```

This is useful for scripts which require Roblox API emulation.

## Testing this project
The repository contains its own unit tests under `test/`.

Run the full test suite:

```sh
lune run src/main.lua
```

Run the runner-specific tests:

```sh
lune run src/main.lua --manifest test/runner/manifest.lua
```
