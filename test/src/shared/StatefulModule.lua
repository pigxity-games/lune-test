local m = {}

local count = 0

function m.getCount()
	return count
end

function m.increment()
	count += 1
	return count
end

return m
