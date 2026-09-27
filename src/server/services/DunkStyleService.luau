local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Styles = require(ReplicatedStorage.Shared.Config.DunkStyles)
local PlayerService = require(script.Parent.PlayerService)
local remote = ReplicatedStorage.Remotes.EquipDunkStyle

local DunkStyleService = {}
local nextRequest = {}
local initialized = false

function DunkStyleService.Init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerRemoving:Connect(function(player)
		nextRequest[player] = nil
	end)
	remote.OnServerEvent:Connect(function(player, styleId, ...)
		if player.Parent ~= Players or os.clock() < (nextRequest[player] or 0) then
			return
		end
		nextRequest[player] = os.clock() + Styles.EquipCooldownSeconds
		local accepted, message = false, "Invalid request."
		if select("#", ...) == 0 and type(styleId) == "string" and #styleId <= 32 then
			accepted, message = PlayerService.EquipDunkStyle(player, styleId)
		end
		remote:FireClient(player, accepted, message, PlayerService.GetEquippedDunkStyle(player))
	end)
end

return DunkStyleService
