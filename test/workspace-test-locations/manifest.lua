return {
	workspaces = {
		game = {
			rojoProject = "./game.project.json",
			testLocations = { "./game/unit/*_unit" },
		},
		hub = {
			rojoProject = "./hub.project.json",
			testLocations = { "./hub/unit/*_unit" },
		},
	},
}
