return {
	testLocations = { "./**/test_*" },
	tests = {
		test_runner_core = {
			module = "./test_runner_core",
			cases = {
				caseArgumentsArePassedThrough = { 7, 3, 4 },
				singleLiteralCaseArgumentIsPassedThrough = "hello",
				lazyTableCaseArgumentsArePassedThrough = function()
					return { 9, 4, 5 }
				end,
				lazySingleCaseArgumentIsPassedThrough = function()
					return "lazy"
				end,
			},
		},
	},
	mounts = {
		ReplicatedStorage = "test/fixture-main/src/shared",
		ServerScriptService = "./src/server",
		PlayerScripts = "./src/client",
	},
}
