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

local function runSuite(output, testName: string, testData)
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

local function runManifestSelection(output, manifest, requestedSuiteName: string?)
	local matched = false

	for testName, testData in pairs(manifest.tests) do
		if requestedSuiteName == nil or requestedSuiteName == testName then
			matched = true
			runSuite(output, testName, testData)
		end
	end

	if requestedSuiteName ~= nil and not matched then
		error(`unknown test suite: {requestedSuiteName}`, 0)
	end
end

local function runScriptSelection(output, selection)
	output.beginSuite(selection.displayName)

	local scriptSandbox = sandbox.create(selection.mounts)
	scriptSandbox.install()

	local success, result = xpcall(function()
		local oldCurrentFilePath = scriptSandbox.globals.__currentFilePath
		scriptSandbox.globals.__currentFilePath = selection.filePath

		local scriptResult = scriptSandbox.loadFileModule(selection.filePath)

		scriptSandbox.globals.__currentFilePath = oldCurrentFilePath

		return scriptResult
	end, withTraceback)

	scriptSandbox.uninstall()
	output.recordCase(selection.displayName, "run", success, result)
	output.finishSuite()
end

function runner.runSelections(selections)
	local hasScriptSelection = false
	local hasNonScriptSelection = false

	for _, selection in ipairs(selections) do
		if selection.kind == "script" then
			hasScriptSelection = true
		else
			hasNonScriptSelection = true
		end
	end

	local scriptOnly = hasScriptSelection and not hasNonScriptSelection
	local output = reporter.create({
		printSuites = not scriptOnly,
		printCases = not scriptOnly,
		printSummary = not scriptOnly,
	})

	for _, selection in ipairs(selections) do
		if selection.kind == "manifest" then
			runManifestSelection(output, selection.manifest, nil)
		elseif selection.kind == "suite" then
			runManifestSelection(output, selection.manifest, selection.suiteName)
		elseif selection.kind == "script" then
			runScriptSelection(output, selection)
		else
			error(`unknown selection kind: {tostring(selection.kind)}`, 0)
		end
	end

	output.printSummary()

	return output.getResults()
end

function runner.runManifest(manifest, requestedSuiteName: string?)
	local selections = {
		{
			kind = if requestedSuiteName == nil then "manifest" else "suite",
			manifest = manifest,
			suiteName = requestedSuiteName,
		},
	}

	return runner.runSelections(selections)
end

return runner
