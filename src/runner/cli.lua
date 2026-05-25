local paths = require("./paths")

local cli = {}

local function trim(value: string): string
	return value:match("^%s*(.-)%s*$")
end

local function splitSelections(selectionArgument: string): { string }
	local selections = {}

	for selection in selectionArgument:gmatch("[^,]+") do
		selection = trim(selection)

		if selection ~= "" then
			table.insert(selections, selection)
		end
	end

	return selections
end

function cli.parseArgs(args)
	local options = {
		manifestPath = nil,
		workspaceName = nil,
		selections = {},
		scriptArgs = {},
	}
	local positionals = {}
	local index = 1

	while index <= #args do
		local arg = args[index]

		if arg == "-m" or arg == "--manifest" then
			index += 1
			assert(index <= #args, `${arg} requires a value`)
			options.manifestPath = args[index]
		elseif arg:match("^%-%-manifest=") then
			options.manifestPath = arg:sub(#"--manifest=" + 1)
		elseif arg == "-w" or arg == "--workspace" then
			index += 1
			assert(index <= #args, `${arg} requires a value`)
			options.workspaceName = args[index]
		elseif arg:match("^%-%-workspace=") then
			options.workspaceName = arg:sub(#"--workspace=" + 1)
		elseif arg == "-a" then
			for argIndex = index + 1, #args do
				table.insert(options.scriptArgs, args[argIndex])
			end
			break
		else
			table.insert(positionals, arg)
		end

		index += 1
	end

	assert(#positionals <= 1, "expected at most one positional argument")

	if positionals[1] ~= nil then
		options.selections = splitSelections(positionals[1])
	end

	return options
end

function cli.isScriptSelection(selection: string): boolean
	return paths.isSourceFilePath(selection) or paths.resolveExistingSourceFile(selection) ~= nil
end

return cli
