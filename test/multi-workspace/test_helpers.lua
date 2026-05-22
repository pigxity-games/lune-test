local m = {}

function m.getPath(root, ...)
	local node = root

	for _, segment in ipairs({ ... }) do
		if node == nil then
			return nil
		end

		node = node[segment]
	end

	return node
end

return m
