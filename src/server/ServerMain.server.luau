local PlayerService = require(script.Parent.services.PlayerService)
local TrainingService = require(script.Parent.services.TrainingService)
local BasketballService = require(script.Parent.services.BasketballService)
local DunkService = require(script.Parent.services.DunkService)
local UpgradeService = require(script.Parent.services.UpgradeService)

PlayerService.Init()
TrainingService.Init()
BasketballService.Init()
DunkService.Init()
UpgradeService.Init()

print("[DunkSimulator] Vertical progression initialized (session-only data).")
