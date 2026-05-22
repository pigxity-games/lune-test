return {
	tests = {
		test_module_requires = {
			module = "./test_module_requires",
			cases = {
				addFunctionAddsTwoNumbers = {}
			}
		},
		test_sandboxing = {
			module = "./test_sandboxing",
			cases = {
				sandboxedGlobalState1 = {},
				sandboxedGlobalState2 = {}
			}
		},
		test_runner_core = {
			module = "./test_runner_core",
			cases = {
				mountsServicesIntoGlobals = {},
				instanceRequireResolvesNestedModuleScripts = {},
				moduleStateStartsFreshPerCase1 = {},
				moduleStateStartsFreshPerCase2 = {},
				serviceTreeStartsFreshPerCase1 = {},
				serviceTreeStartsFreshPerCase2 = {},
				caseArgumentsArePassedThrough = { 7, 3, 4 },
				singleLiteralCaseArgumentIsPassedThrough = "hello",
				lazyTableCaseArgumentsArePassedThrough = function()
					return { 9, 4, 5 }
				end,
				lazySingleCaseArgumentIsPassedThrough = function()
					return "lazy"
				end,
			}
		}
	},
	mounts = {
		ReplicatedStorage = "test/src/shared",
		ServerScriptService = "test/src/server"
	}
}
