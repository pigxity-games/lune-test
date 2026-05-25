local ok, err = pcall(function()
	require(script.Parent.InvalidPath)
end)

return {
	ok = ok,
	err = tostring(err),
}
