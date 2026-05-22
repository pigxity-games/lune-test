local process = require("@lune/process")

local manifestRunner = require("./runner/manifest")
local runner = require("./runner/run")

local function fail(err)
	print(tostring(err))
	process.exit(1)
end

local manifestPath = process.args[1]
local requestedSuiteName = process.args[2]

assert(manifestPath, "usage: lune run lune-test <manifest.lua> [suite-name]")

local ok, manifestOrErr, normalizedManifestPath = pcall(manifestRunner.loadManifest, manifestPath)

if not ok then
	fail(manifestOrErr)
end

local runOk, runErr = pcall(runner.runManifest, manifestOrErr, normalizedManifestPath, requestedSuiteName)

if not runOk then
	fail(runErr)
end
