# CLI Usage

By default, `lune-test` looks for `test/manifest.lua` from the current working directory.

```sh
lune run lune-test
```

## Manifest selection

Use `-m` or `--manifest` to point at a manifest file.

```sh
lune run lune-test --manifest test/manifest.lua
lune run lune-test -m test/manifest.lua
lune run lune-test --manifest=test/manifest.lua
```

The manifest path can include or omit a `.lua` or `.luau` extension.

## Running suites

The first positional argument is a comma-separated list of selections. A selection can be a suite name or a script file.

```sh
lune run lune-test test_runner_core
lune run lune-test test_runner_core,test_fake_runtime
```

When no positional argument is given, every suite in the selected manifest is run.

## Running scripts

A selection can also be a `.lua` or `.luau` file. Script selections run in a sandbox with the same fake globals and mounted require behavior as tests.

```sh
lune run lune-test test/fixture-main/scripts/uses_modules.lua
```

When a script is selected without `--manifest`, the runner searches upward from that script for the nearest `manifest.lua` or `manifest.luau`. If none is found, it falls back to `test/manifest.lua`.

Pass script arguments after `-a`. Everything after the flag is forwarded to the script.

```sh
lune run lune-test test/runner/fixtures/script_args/first.lua -a hello world
```

`-a` requires at least one script selection.

## Workspaces

Use `-w` or `--workspace` to run a script or suite using a named manifest workspace.

```sh
lune run lune-test --manifest test/multi-workspace/manifest.lua --workspace game game_tests
lune run lune-test -m test/multi-workspace/manifest.lua -w hub test/multi-workspace/scripts/hub_script.lua
```

For script selections, a workspace is required when the manifest has no top-level mounts and the runner cannot infer one from the script path. If a manifest has top-level mounts, those mounts are used unless `--workspace` is provided.

## Output

Test selections print suites, cases, and a summary. Script-only selections keep output quieter and print a summary only when the script fails.
