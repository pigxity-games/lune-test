local caseArgs = require("./case_args")
local reporter = require("./reporter")
local sandbox = require("./sandbox")

local runner = {}

local function withTraceback(err)
	return debug.traceback(tostring(err), 2)
end

local function loadTestModule(caseSandbox, testData)
	return if testData.moduleIsFile
		then caseSandbox.loadFileModule(testData.module)
		else caseSandbox.require(testData.module)
end

local function discoverCaseNames(caseSandbox, testData)
	if not testData.discoverCases then
		local caseNames = {}

		for caseName in pairs(testData.cases) do
			table.insert(caseNames, caseName)
		end

		return caseNames
	end

	local module = loadTestModule(caseSandbox, testData)
	local caseNames = {}

	for exportName, exportValue in pairs(module) do
		if type(exportName) == "string" and type(exportValue) == "function" then
			table.insert(caseNames, exportName)
		end
	end

	return caseNames
end

function runner.runManifest(manifest, requestedSuiteName: string?)
	local output = reporter.create()

	for testName, testData in pairs(manifest.tests) do
		if requestedSuiteName == nil or requestedSuiteName == testName then
			output.beginSuite(testName)

			local discoverySandbox = sandbox.create(testData.mounts)
			discoverySandbox.install()
			discoverySandbox.globals.__currentFilePath = if testData.moduleIsFile then testData.module else nil
			local caseNames = discoverCaseNames(discoverySandbox, testData)
			discoverySandbox.uninstall()

			for _, caseName in ipairs(caseNames) do
				local deps = testData.cases[caseName]
				local caseSandbox = sandbox.create(testData.mounts)
				caseSandbox.install()

				local success, result = xpcall(function()
					local oldCurrentFilePath = caseSandbox.globals.__currentFilePath
					caseSandbox.globals.__currentFilePath = if testData.moduleIsFile then testData.module else nil

					local module = loadTestModule(caseSandbox, testData)
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
