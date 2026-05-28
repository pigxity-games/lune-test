# lune-test
is a test runner for the `lune` runtime. It attempts to emulate Roblox APIs and globals to allow Roblox-specific code to run in local luau environments.

**[DOCUMENTATION](https://pigxity-games.github.io/lune-test)**

Features:

- Roblox instance-based requires and require-by-string support, allowing mounting of files onto Roblox services.
- A fake Roblox environment, which emulates the datamodel, common services, and networking. Environments are very customizable, allowing creation of custom mock services.
- Sandboxing and creation of multiple environments in a single script/test with easy swapping.
- Deriving service mounts from a Rojo project file.
- Multiple workspaces in the manifest.
- Luau script running using the same environment and APIs.

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

## Manifests
Manifests are luau modules which return a table. Creating a manifest is required to specify locations of tests and mounting options.

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

## CLI usage
By default, `lune-test` looks for `test/manifest.lua`.

```sh
lune run lune-test
```

You can provide a manifest explicitly with `-m` or `--manifest`:

```sh
lune run lune-test --manifest test/manifest.lua
```

The first positional argument is a comma-separated list of selections. Each selection may be:
- a test suite name from the manifest
- a path to a `.lua` or `.luau` file to run as a sandboxed script

You may also run selections in a specific workspace by passing it with the `-w` or `--workspace` flag.

## Testing this project
The repository contains its own unit tests under `test/`.

```sh
lune run src/main.lua
```
