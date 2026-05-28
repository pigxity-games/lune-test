# Manifest Format

Manifests are Luau modules that return a table. A manifest describes the location of tests and mounting of services.

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

Paths beginning with `.` are resolved relative to the manifest file. Other filesystem paths are normalized.

## Tests

`tests` is a map of suite name to suite definition.

```lua
tests = {
	my_suite = {
		module = "./my_suite",
		cases = {
			oneCase = {},
			anotherCase = { 1, 2, 3 },
		},
	},
}
```

Each suite has:

- `module`: a module path or file path. Relative file paths such as `./my_suite` are resolved from the manifest file. Non-relative module paths are loaded through the sandbox require system.
- `cases`: a map of exported function name to argument data.
- `workspace`: optional workspace name. When set, that suite uses the workspace mounts instead of top-level mounts.

Case argument data is passed to the exported test function:

- `nil` or `{}` passes no arguments.
- A table passes each array item as an argument.
- A non-table value is passed as a single argument.
- A function is called before the case runs, and its return value is treated by the same rules.

```lua
cases = {
	noArguments = {},
	tableArguments = { 7, 3, 4 },
	singleArgument = "hello",
	lazyArguments = function()
		return { 9, 4, 5 }
	end,
}
```

The test module should return a table with functions whose names match the case names:

```lua
return {
	tableArguments = function(total, left, right)
		assert(left + right == total)
	end,
}
```

Every case uses a new sandbox and environment.

## Mounts

`mounts` maps Roblox service paths to filesystem folders.

```lua
mounts = {
	ReplicatedStorage = "./src/shared",
	ServerScriptService = "./src/server",
	PlayerScripts = "./src/client",
}
```

Mounted files become fake `ModuleScript` instances and can be required by instance:

```lua
local module = require(game:GetService("ReplicatedStorage").SomeModule)
```

They can also be required by path:

```lua
local module = require("ReplicatedStorage/SomeModule")
local sameModule = require("@game/ReplicatedStorage/SomeModule")
```

Relative requires are resolved from the current module or script:

```lua
local sibling = require("./SiblingModule")
```

`@self` resolves to the current module folder:

```lua
local child = require("@self/ChildModule")
```

Aliases from `.luaurc` are supported when the alias points at a project-relative path.

Nested mount tables let one service contain multiple roots:

```lua
mounts = {
	ReplicatedStorage = {
		_root = "./src/shared",
		Common = "./src/common/shared",
	},
	ServerScriptService = {
		Game = "./src/server",
	},
}
```

`_root` mounts a folder at the current service path. Other keys continue it.

`PlayerScripts` mounts under `Players.LocalPlayer.PlayerScripts` and `StarterPlayer.StarterPlayerScripts`, allowing client-style requires to work from either location.

## Rojo projects

Use `rojoProject` to derive mounts from a Rojo project file.

```lua
return {
	rojoProject = "default.project.json",
	tests = {
		my_suite = {
			module = "./my_suite",
			cases = {
				works = {},
			},
		},
	},
}
```

The runner reads `tree` entries with `$path` fields and maps them into service paths. `StarterPlayer/StarterPlayerScripts` is normalized to `PlayerScripts`.

`mounts` and `rojoProject` may be used together. Derived Rojo mounts are appended to explicit mounts.

## Test discovery

`testLocations` can discover test suites from file globs.

```lua
return {
	testLocations = {
		"unit/**/*_unit",
	},
	mounts = {
		ReplicatedStorage = "./src/shared",
	},
}
```

Discovered files with `.lua` or `.luau` extensions become suites. Functions inside those modules become cases.

## Workspaces

`workspaces` allows for creation of multiple mount layouts.

```lua
return {
	workspaces = {
		hub = {
			rojoProject = "hub.project.json",
		},

		game = {
			mounts = {
				ReplicatedStorage = {
					Common = "./src/common/shared",
				},
				ServerScriptService = "./src/game/server",
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

A workspace must define either `mounts` or `rojoProject`. Workspace `testLocations` are also supported and use that workspace's mounts.

## Child manifests

`childManifests` loads additional manifests and merges their suites into the parent manifest.

```lua
return {
	childManifests = {
		"./unit/manifest",
		"./integration/manifest",
	},
	mounts = {
		ReplicatedStorage = "./src/shared",
	},
}
```

Suite names must be unique across the parent and all children. Circular child manifest references are rejected.
