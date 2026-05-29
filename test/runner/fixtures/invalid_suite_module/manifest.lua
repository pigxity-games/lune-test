return {
	tests = {
		invalid_suite_module = {
			module = "./syntax_error_suite",
			cases = {
				caseOne = {},
				caseTwo = {},
			},
		},
	},
	mounts = {
		ReplicatedStorage = "../../fixture-main/src/shared",
	},
}
