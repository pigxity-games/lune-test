return {
	tests = {
		test_test = {
			module = "./test_test",
			cases = {
				addFunctionAddsTwoNumbers = {}
			}
		}
	},
	mounts = {
		ReplicatedStorage = "test/src/shared",
		ServerScriptService = "test/src/server"
	}
}