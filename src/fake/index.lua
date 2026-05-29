local Environment = require("./Environment")
local RBXScriptSignal = require("./Signal")

return {
	createEnvironment = function(config)
		local environment = Environment.new(config)

		if
			environment._installController ~= nil
			and config ~= nil
			and (config.availableServices ~= nil or config.serviceOverrides ~= nil)
		then
			environment:install()
		end

		return environment
	end,
	getEnvironment = function()
		return Environment.getActiveEnvironment()
	end,
	Environment = Environment,
	Instance = require("./Instance"),
	RBXScriptSignal = RBXScriptSignal,
	RBXScriptConnection = RBXScriptSignal.RBXScriptConnection,
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
