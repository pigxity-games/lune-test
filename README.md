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
		ReplicatedStorage = "test/src/shared",
		ServerScriptService = "test/src/server"
	}
}
```

Each `cases` value is passed to the named test function as positional arguments.

- A table value like `testCaseFunction1 = { "hello", 123 }` calls `testCaseFunction1("hello", 123)`.
- A single literal value like `testCaseFunction2 = "single value"` calls `testCaseFunction2("single value")`.
- A function value is called lazily at test time, and its return value is normalized the same way.



## Testing
The project contains unit tests under `test/`. Run them with the test runner itself.

```sh
lune run src/main.lua test/test/manifest.lua
```
