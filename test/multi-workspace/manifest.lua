return {
	workspaces = {
		hub = {
			rojoProject = "test/multi-workspace/hub.project.json",
		},

		game = {
			mounts = {
				ReplicatedStorage = {
					_root = "./src/game/shared",
					Common = "./src/common/shared",
				},
				ServerScriptService = {
					Game = "./src/game/server",
					Utils = "test/multi-workspace/src/game/utils",
				},
			},
		},
	},

	tests = {
		hub_tests = {
			workspace = "hub",
			module = "./hub_tests",
			cases = {
				workspaceHubRequires = {},
				hubWorkspaceClientRequires = {},
			},
		},

		game_tests = {
			workspace = "game",
			module = "./game_tests",
			cases = {
				workspaceGameRequires = {},
				gameWorkspaceShared = {},
			},
		},

		common_hub_tests = {
			workspace = "hub",
			module = "./common_tests",
			cases = {
				otherWorkspaceModulesNil = {
					{ "ServerScriptService", "Game", "SomeGameModule" },
					{ "ServerScriptService", "Utils", "SharedGameModule" },
				},
				commonSharedModuleDividesTwoNumbers = { 12, 3, 4 },
			},
		},

		common_game_tests = {
			workspace = "game",
			module = "./common_tests",
			cases = {
				otherWorkspaceModulesNil = {
					{ "ServerScriptService", "SomeHubModule" },
					{ "StarterPlayer", "StarterPlayerScripts", "ClientModule" },
				},
				commonSharedModuleDividesTwoNumbers = { 81, 9, 9 },
			},
		},
	},
}
