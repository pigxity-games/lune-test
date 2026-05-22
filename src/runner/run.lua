local caseArgs = require("./case_args")
local reporter = require("./reporter")
local sandbox = require("./sandbox")

local runner = {}

local function withTraceback(err)
	return debug.traceback(tostring(err), 2)
end

function runner.runManifest(manifest, requestedSuiteName: string?)
	local output = reporter.create()

	for testName, testData in pairs(manifest.tests) do
		if requestedSuiteName == nil or requestedSuiteName == testName then
			output.beginSuite(testName)

			for caseName, deps in pairs(testData.cases) do
				local caseSandbox = sandbox.create(testData.mounts)
				caseSandbox.install()

				local success, result = xpcall(function()
					local oldCurrentFilePath = caseSandbox.globals.__currentFilePath
					caseSandbox.globals.__currentFilePath = if testData.moduleIsFile then testData.module else nil

					local module = if testData.moduleIsFile
						then caseSandbox.loadFileModule(testData.module)
						else caseSandbox.require(testData.module)
					local caseResult = module[caseName](unpack(caseArgs.fromValue(deps)))

					caseSandbox.globals.__currentFilePath = oldCurrentFilePath

					return caseResult
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
