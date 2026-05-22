# lune-test
A test runner script written for the lune runtime which aims to replicate a roblox environment. It features path resolution from Roblox instance-based requires and emulation of common classes such as Color3, Vector3, and Instance.

## Installation
- Download the lua bundle file from GitHub releases
- Place it in `~/.lune` to allow for easy running

Or build the bundle from source:
```sh
git clone https://github.com/pigxity-games/lune-test
cd lune-test
rokit install
darklua process src/main.lua dist/lune-test.luau
```

## Usage
The script accepts a path to a `manifest.lua` file and an optional test suite name.

You may run the script as follows:
```sh
lune run lune-test test/manifest.lua
```

To run just one suite from `manifest.tests`, pass its name as the second argument:

```sh
lune run lune-test test/manifest.lua test_runner_core
```

`manifest` should be a lua file which contains a table such as the following:

```lua
return {
	tests = {
		test_1 = {
			module = "./test_1",
			cases = {
				testCaseFunction1 = { "hello", 123 },
				testCaseFunction2 = "single value",
				testCaseFunction3 = function()
					return { true, "lazy args" }
				end,
				testCaseFunction4 = function()
					return "lazy single value"
				end,
			}
		},
		test_2 = {
			module = "./test_2",
			cases = {
				testCaseFunction2 = {},
				testCaseFunction3 = { true, "abc" }
			}
		},
	},
	mounts = {
		ReplicatedStorage = "./src/shared",
		ServerScriptService = "./src/server",
		PlayerScripts = "./src/client",
	}
}
```

Each `cases` value is passed to the named test function as positional arguments.

- A table value like `testCaseFunction1 = { "hello", 123 }` calls `testCaseFunction1("hello", 123)`.
- A single literal value like `testCaseFunction2 = "single value"` calls `testCaseFunction2("single value")`.
- A function value is called lazily at test time, and its return value is normalized the same way.

Mount paths are relative to the manifest file when they are not absolute.

## Manifest features / multiple workspaces
Manifests also support more features beyond `tests` and `mounts`.

### Child manifests

```lua
return {
	childManifests = {
		"./fixture-main/manifest",
		"./multi-workspace/manifest",
	},
}
```

Child manifest paths must be relative to the parent manifest file.

### Workspaces

```lua
return {
	workspaces = {
		hub = {
			mounts = {
				ReplicatedStorage = "./src/hub/shared"
				ServerScriptService = "./src/hub/server"
			},
		},

		game = {
			mounts = {
				ReplicatedStorage = "src/game/shared" --supports both ./ and no prefix
				ServerScriptService = "src/game/server"
			},
		},
	},

	tests = {
		hub_tests = {
			workspace = "hub",
			module = "./hub_tests",
			cases = {
				...
			},
		},
	},
}
```

If a suite sets `workspace`, it uses mounts from that workspace. Otherwise, it uses the default manifest `mounts`.

### Nested mounts
Nested mount tables let you mount paths to children in a service:

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

You can use `_root` to mount a service itself, while also including child mounts:

```lua
mounts = {
	ReplicatedStorage = {
		_root = "src/shared",
		Common = "src/common/shared",
	},
}
```

### Rojo workspaces
Workspace definitions may use `rojoProject` instead of `mounts`:

```lua
workspaces = {
	hub = {
		rojoProject = "./hub.project.json",
	},
}
```

The loader reads `$path` entries from the Rojo tree and turns them into mounts automatically. 

Note that `StarterPlayer.StarterPlayerScripts` is exposed as `Players.LocalPlayer.PlayerScripts`.


## Testing
The project contains unit tests under `test/`. Run them with the test runner itself.

```sh
lune run src/main.lua test/manifest.lua
```
