local m = {}

function m.add(a: number, b: number)
	return a + b
end

function m.assertEqual(actual, expected, message)
	assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

function m.assertSequenceEqual(actual, expected, label)
	m.assertEqual(#actual, #expected, string.format("%s length mismatch", label or "sequence"))

	for index, expectedValue in ipairs(expected) do
		m.assertEqual(
			actual[index],
			expectedValue,
			string.format("%s mismatch at index %d", label or "sequence", index)
		)
	end
end

function m.assertNameSetEqual(actual, expectedNames, label)
	m.assertEqual(#actual, #expectedNames, string.format("%s length mismatch", label or "name set"))

	local seen = {}
	for _, instance in ipairs(actual) do
		seen[instance.Name] = (seen[instance.Name] or 0) + 1
	end

	for _, expectedName in ipairs(expectedNames) do
		m.assertEqual(seen[expectedName], 1, string.format("%s missing %s", label or "name set", expectedName))
	end
end

function m.assertContains(haystack: string, needle: string, label)
	assert(
		haystack:find(needle, 1, true) ~= nil,
		label or string.format('expected "%s" to contain "%s"', haystack, needle)
	)
end

function m.assertError(fun, contains)
	local ok, err = pcall(fun)
	assert(not ok)
	if contains then
		m.assertContains(err, contains)
	end
end

function m.assertErrorContainsOneOf(fun, expectedMessages, label)
	local ok, err = pcall(fun)
	assert(not ok, label or "expected function to error")

	for _, expectedMessage in ipairs(expectedMessages) do
		if tostring(err):find(expectedMessage, 1, true) ~= nil then
			return
		end
	end

	error(
		label
			or string.format(
				'expected "%s" to contain one of: %s',
				tostring(err),
				table.concat(expectedMessages, ", ")
			),
		0
	)
end

function m.assertRequireError(callback, expectedMessage: string)
	local ok, err = pcall(callback)
	assert(not ok, "expected require to error")
	m.assertContains(tostring(err), expectedMessage)
end

function m.assertClose(actual, expected, epsilon, label)
	local difference = math.abs(actual - expected)
	assert(
		difference <= epsilon,
		string.format("%s expected %.6f, got %.6f (difference %.6f)", label or "value", expected, actual, difference)
	)
end

function m.assertVector2Equal(actual, x, y)
	m.assertEqual(actual, Vector2.new(x, y))
end

function m.assertVector3Equal(actual, x, y, z)
	m.assertEqual(actual, Vector3.new(x, y, z))
end

function m.assertUDimEqual(actual, scale, offset)
	m.assertEqual(actual, UDim.new(scale, offset))
end

function m.assertUDim2Equal(actual, xScale, xOffset, yScale, yOffset)
	m.assertEqual(actual, UDim2.new(xScale, xOffset, yScale, yOffset))
end

function m.assertColor3Equal(actual, expected)
	m.assertEqual(actual, expected, string.format("expected Color3 %s, got %s", tostring(expected), tostring(actual)))
end

return m
