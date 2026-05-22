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
			}
		}
	},
	mounts = {
		ReplicatedStorage = "test/src/shared",
		ServerScriptService = "test/src/server"
	}
}
