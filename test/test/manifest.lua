return {
	tests = {
		test_test = {
			module = "./test_module_requires",
			cases = {
				addFunctionAddsTwoNumbers = {}
			}
		},
		test_test2 = {
			module = "./test_sandboxing",
			cases = {
				sandboxedGlobalState1 = {},
				sandboxedGlobalState2 = {}
			}
		}
	},
	mounts = {
		ReplicatedStorage = "test/src/shared",
		ServerScriptService = "test/src/server"
	}
}