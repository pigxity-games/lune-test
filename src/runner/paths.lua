local fs = require("@lune/fs")
local process = require("@lune/process")

local paths = {}

function paths.isAbsoluteFilesystemPath(path: string): boolean
	return path:match("^/") ~= nil or path:match("^%a:[/]") ~= nil
end

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

	if not paths.isAbsoluteFilesystemPath(path) then
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

function paths.resolveFilesystemPathFromFile(baseFilePath: string, targetPath: string): string
	if paths.isAbsoluteFilesystemPath(targetPath) then
		return paths.normalizeFilesystemPath(targetPath)
	end

	return paths.normalizeFilesystemPath(paths.pathJoin(paths.dirname(baseFilePath), targetPath))
end

function paths.resolveManifestResourcePath(baseFilePath: string, targetPath: string): string
	if targetPath:sub(1, 2) == "./" then
		return paths.normalizeFilesystemPath(paths.pathJoin(paths.dirname(baseFilePath), targetPath))
	end

	return paths.normalizeFilesystemPath(targetPath)
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

function paths.isSourceFilePath(path: string): boolean
	return path:match("%.luau?$") ~= nil
end

function paths.sourceFilePathWithoutExtension(path: string): string
	return paths.normalizeFilesystemPath(path:gsub("%.luau$", ""):gsub("%.lua$", ""))
end

function paths.resolveExistingSourceFile(path: string): string?
	local normalizedPath = paths.sourceFilePathWithoutExtension(path)

	if fs.isFile(normalizedPath .. ".lua") then
		return normalizedPath .. ".lua"
	end

	if fs.isFile(normalizedPath .. ".luau") then
		return normalizedPath .. ".luau"
	end

	return nil
end

function paths.relativeFilesystemPath(basePath: string, targetPath: string): string?
	local baseParts = paths.splitPath(paths.normalizeFilesystemPath(basePath))
	local targetParts = paths.splitPath(paths.normalizeFilesystemPath(targetPath))

	if #targetParts < #baseParts then
		return nil
	end

	for index, basePart in ipairs(baseParts) do
		if targetParts[index]:lower() ~= basePart:lower() then
			return nil
		end
	end

	local relativeParts = {}

	for index = #baseParts + 1, #targetParts do
		table.insert(relativeParts, targetParts[index])
	end

	return table.concat(relativeParts, "/")
end

return paths
