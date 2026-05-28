# lune-test
`lune-test` is a test runner for the `lune` runtime. It attempts to emulate Roblox APIs and globals to allow Roblox-specific code to run in local Luau environments.

It is built for Roblox code that expects `game`, `Instance`, services, datatypes, `task`, and Roblox-style `require` behavior. Each test case runs in a fresh sandbox, so module state, service trees, fake players, remotes, and scheduled tasks can be set up without leaking into another case.

## Features

- Roblox instance-based requires and require-by-string support, allowing mounting of files onto Roblox services.
- A fake Roblox environment, which emulates the datamodel, common services, and networking. Environments are very customizable, allowing creation of custom mock services.
- Sandboxing and creation of multiple environments in a single script/test with easy swapping.
- Deriving service mounts from a Rojo project file.
- Multiple workspaces in the manifest.
- Luau script running using the same environment and APIs.

## Installation

Download the bundled Lua file from GitHub releases and place it in `~/.lune` for easy execution.

Or build it from source:

```sh
git clone https://github.com/pigxity-games/lune-test
cd lune-test
rokit install
darklua process src/main.lua dist/lune-test.luau
```

The repository contains its own unit tests under `test/`.

```sh
lune run src/main.lua
```

## Pages

- [CLI Usage](./cli_usage)
- [Manifest Format](./manifest)
- [Environment API](./environment/)
