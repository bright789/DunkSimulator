-- Saved player settings (schema v11 `Settings`). Clients may only send
-- SettingsRequest("Music", boolean); the value is stored in PlayerService and saved with the
-- rest of the profile (a priority save follows each change).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)

local SettingsService = {}
local initialized = false
local nextRequest: { [Player]: number } = {}

function SettingsService.Init()
	if initialized then return end
	initialized = true
	ReplicatedStorage.Remotes.SettingsRequest.OnServerEvent:Connect(function(player, key, value, ...)
		if key ~= "Music" or type(value) ~= "boolean" or select("#", ...) ~= 0 then return end
		if os.clock() < (nextRequest[player] or 0) then return end
		nextRequest[player] = os.clock() + 0.5
		if PlayerService.SetMusicSetting(player, value) then DataService.RequestSave(player) end
	end)
	Players.PlayerRemoving:Connect(function(player) nextRequest[player] = nil end)
end

return SettingsService
