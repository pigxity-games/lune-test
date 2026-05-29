local modules = {
	require("./environment_cases"),
	require("./instance_cases"),
	require("./signal_and_collection_cases"),
	require("./networking_cases"),
	require("./player_cases"),
	require("./scheduler_and_memory_cases"),
	require("./docs_cases"),
}

local m = {}

local function mergeExports(exports)
	for exportName, exportValue in pairs(exports) do
		assert(m[exportName] == nil, `duplicate runtime test export: {exportName}`)
		m[exportName] = exportValue
	end
end

for _, exports in ipairs(modules) do
	mergeExports(exports)
end

return m
