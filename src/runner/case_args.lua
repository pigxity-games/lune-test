local caseArgs = {}

function caseArgs.fromValue(caseValue)
	if type(caseValue) == "function" then
		caseValue = caseValue()
	end

	if caseValue == nil then
		return {}
	end

	if type(caseValue) == "table" then
		return caseValue
	end

	return { caseValue }
end

return caseArgs
