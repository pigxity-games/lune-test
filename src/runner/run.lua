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

local function loadSuiteModuleOnce(testData)
	local discoverySandbox = sandbox.create(testData.mounts, testData.environment)
	discoverySandbox.install()

	local success, result = xpcall(function()
		discoverySandbox.globals.__currentFilePath = if testData.moduleIsFile then testData.module else nil
		return loadTestModule(discoverySandbox, testData)
	end, withTraceback)

	discoverySandbox.uninstall()

	if not success then
		error(result, 0)
	end

	return result
end

local function discoverCaseNames(testData, module)
	if not testData.discoverCases then
		local caseNames = {}

		for caseName in pairs(testData.cases) do
			table.insert(caseNames, caseName)
		end

		return caseNames
	end

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

	local suiteModule = loadSuiteModuleOnce(testData)
	local caseNames = discoverCaseNames(testData, suiteModule)

	for _, caseName in ipairs(caseNames) do
		local deps = testData.cases[caseName]
		local caseSandbox = sandbox.create(testData.mounts, testData.environment)
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

local function resolveRequestedSuite(manifest, requestedSuiteName: string)
	local exactMatch = manifest.tests[requestedSuiteName]

	if exactMatch ~= nil then
		return requestedSuiteName, exactMatch
	end

	local matchedSuiteName = nil
	local matchedSuite = nil

	for testName, testData in pairs(manifest.tests) do
		local basename = testName:match("([^/]+)$")

		if basename == requestedSuiteName then
			assert(matchedSuiteName == nil, `ambiguous test suite: {requestedSuiteName}`)
			matchedSuiteName = testName
			matchedSuite = testData
		end
	end

	if matchedSuiteName == nil then
		error(`unknown test suite: {requestedSuiteName}`, 0)
	end

	return matchedSuiteName, matchedSuite
end

local function runManifestSelection(output, manifest, requestedSuiteName: string?)
	if requestedSuiteName ~= nil then
		local matchedSuiteName, matchedSuite = resolveRequestedSuite(manifest, requestedSuiteName)
		runSuite(output, matchedSuiteName, matchedSuite)
		return
	end

	for testName, testData in pairs(manifest.tests) do
		runSuite(output, testName, testData)
	end
end

local function runScriptSelection(output, selection)
	output.beginSuite(selection.displayName)

	local scriptSandbox = sandbox.create(selection.mounts, selection.environment)
	scriptSandbox.install()

	local success, result = xpcall(function()
		local oldCurrentFilePath = scriptSandbox.globals.__currentFilePath
		scriptSandbox.globals.__currentFilePath = selection.filePath

		local scriptResult = scriptSandbox.loadFileModule(selection.filePath, nil, unpack(selection.scriptArgs or {}))

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

	local results = output.getResults()

	if scriptOnly then
		if not results.success then
			output.printSummary(true)
		end
	else
		output.printSummary()
	end

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
