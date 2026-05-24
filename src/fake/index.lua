local Environment = require("./Environment")

return {
	createEnvironment = function(config)
		return Environment.new(config)
	end,
	getEnvironment = function()
		return Environment.getActiveEnvironment()
	end,
	Environment = Environment,
	Instance = require("./Instance"),
	Signal = require("./Signal"),
	Scheduler = require("./Scheduler"),
	Color3 = require("./Color3"),
	Vector2 = require("./Vector2"),
	Vector3 = require("./Vector3"),
	CFrame = require("./CFrame"),
	UDim = require("./UDim"),
	UDim2 = require("./UDim2"),
	BrickColor = require("./BrickColor"),
	Random = require("./Random"),
}
