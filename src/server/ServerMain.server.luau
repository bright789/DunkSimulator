local PlayerService = require(script.Parent.services.PlayerService)
local TrainingService = require(script.Parent.services.TrainingService)
local BasketballService = require(script.Parent.services.BasketballService)
local DunkService = require(script.Parent.services.DunkService)

PlayerService.Init()
TrainingService.Init()
BasketballService.Init()
DunkService.Init()

print("[DunkSimulator] Vertical progression initialized (session-only data).")
