local stdio = require("@lune/stdio")

local reporter = {}

local function boolToColor(success: boolean): string
	return if success then "green" else "red"
end

local function colorText(color: string, text: string): string
	return `{stdio.color(color)}{text}{stdio.color("reset")}`
end

local function seperator(n: number)
	return string.rep("-", n or 25)
end

function reporter.create(options)
	options = options or {}

	local state = {
		errors = {},
		summary = {},
		totalSuccess = 0,
		total = 0,
		matchedSuiteCount = 0,
	}
	local printSuites = options.printSuites ~= false
	local printCases = options.printCases ~= false
	local printSummary = options.printSummary ~= false

	local api = {}

	function api.beginSuite(testName: string)
		state.matchedSuiteCount += 1
		if printSuites then
			print(`[TEST]: {testName}`)
		end
	end

	function api.finishSuite()
		if printSuites or printCases then
			print("")
		end
	end

	function api.recordCase(testName: string, caseName: string, success: boolean, result: string?)
		state.total += 1

		if printCases then
			local text = if success then "PASS" else "FAIL"
			print("- " .. colorText(boolToColor(success), `[{text}]: {caseName}`))
		end

		if success then
			state.totalSuccess += 1
			return
		end

		local errorText = tostring(result):gsub("\n+$", "")
		table.insert(state.summary, colorText("red", testName .. "." .. caseName))
		table.insert(
			state.errors,
			"'" .. colorText("blue", caseName) .. "'" .. colorText("red", "\nTRACEBACK:\n" .. errorText)
		)
	end

	function api.getMatchedSuiteCount(): number
		return state.matchedSuiteCount
	end

	function api.printSummary(force: boolean?)
		if not printSummary and not force then
			return
		end

		if #state.errors > 0 then
			print(seperator())
			print("COLLECTED ERRORS:")
			print("")
			print(table.concat(state.errors, "\n\n") .. "\n")
		end

		if #state.summary > 0 then
			print("FAILED TESTS:")
			print(table.concat(state.summary, "\n"))
			print("")
		end

		local success = state.totalSuccess == state.total
		print(seperator())
		print("TEST RESULTS: " .. colorText(boolToColor(success), `{state.totalSuccess}/{state.total}`) .. "\n")
	end

	function api.getResults()
		return {
			total = state.total,
			totalSuccess = state.totalSuccess,
			matchedSuiteCount = state.matchedSuiteCount,
			success = state.totalSuccess == state.total,
			errors = table.concat(state.errors, "\n"),
			summary = table.concat(state.summary, "\n"),
		}
	end

	return api
end

return reporter
