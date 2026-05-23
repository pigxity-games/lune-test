local Players = game:GetService("Players")
local ClientModule = require(Players.LocalPlayer.PlayerScripts.ClientModule)

assert(ClientModule.half(10) == 5)
