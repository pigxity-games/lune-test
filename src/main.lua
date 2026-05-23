local process = require("@lune/process")

local command = require("./runner/command")

local function fail(err)
	print(tostring(err))
	process.exit(1)
end

local runOk, runErr = pcall(command.run, process.args)

if not runOk then
	fail(runErr)
end
