local process = require("@lune/process")

local paths = {}

function paths.pathJoin(...: string): string
	local parts = { ... }
	local path = table.concat(parts, "/")
	path = path:gsub("\\", "/")
	path = path:gsub("/+", "/")
	return path
end

function paths.dirname(path: string): string
	local dir = path:match("^(.*)/[^/]+$")

	if dir == nil or dir == "" then
		return "."
	end

	return dir
end

function paths.normalizeFilesystemPath(path: string): string
	path = path:gsub("\\", "/")

	if not path:match("^/") and not path:match("^%a:[/]") then
		path = paths.pathJoin(process.cwd, path)
	end

	return path
end

function paths.resolvePathFromFile(baseFilePath: string, targetPath: string): string
	if targetPath:sub(1, 1) == "." then
		return paths.normalizeFilesystemPath(paths.pathJoin(paths.dirname(baseFilePath), targetPath))
	end

	return targetPath
end

function paths.splitPath(path: string): { string }
	local parts = {}

	for part in path:gsub("\\", "/"):gmatch("[^/]+") do
		if part ~= "" and part ~= "." then
			if part == ".." then
				table.remove(parts)
			else
				table.insert(parts, part)
			end
		end
	end

	return parts
end

function paths.joinParts(parts: { string }): string
	return table.concat(parts, "/")
end

function paths.normalizeRequirePath(path: string): string
	path = path:gsub("\\", "/")
	path = path:gsub("%.luau$", "")
	path = path:gsub("%.lua$", "")
	path = path:gsub("/+$", "")

	return paths.joinParts(paths.splitPath(path))
end

return paths
