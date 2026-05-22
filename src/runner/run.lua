local caseArgs = require("./case_args")
local paths = require("./paths")
local reporter = require("./reporter")
local sandbox = require("./sandbox")

local runner = {}

local function withTraceback(err)
	return debug.traceback(tostring(err), 2)
end

function runner.runManifest(manifest, manifestFilePath: string, requestedSuiteName: string?)
	local output = reporter.create()

	for testName, testData in pairs(manifest.tests) do
		if requestedSuiteName == nil or requestedSuiteName == testName then
			output.beginSuite(testName)

			local modulePath = paths.resolvePathFromFile(manifestFilePath, testData.module)

			for caseName, deps in pairs(testData.cases) do
				local caseSandbox = sandbox.create(manifest)
				caseSandbox.install()

				local success, result = xpcall(function()
					local module = if testData.module:sub(1, 1) == "."
						then caseSandbox.loadFileModule(modulePath)
						else caseSandbox.require(testData.module)
					return module[caseName](unpack(caseArgs.fromValue(deps)))
				end, withTraceback)

				caseSandbox.uninstall()
				output.recordCase(testName, caseName, success, result)
			end

			output.finishSuite()
		end
	end

	if requestedSuiteName ~= nil and output.getMatchedSuiteCount() == 0 then
		error(`unknown test suite: {requestedSuiteName}`, 0)
	end

	output.printSummary()

	return output.getResults()
end

return runner
